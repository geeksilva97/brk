//! Native implementations of the SessionStart and title hooks.

use serde::Deserialize;
use serde_json::{Map, Value, json};
use std::env;
use std::ffi::{OsStr, OsString};
use std::fs;
use std::io::{self, Write};
use std::path::{Component, Path, PathBuf};

use crate::state;

const USAGE: &str =
    "usage: brk hook <session-start|title> --plugin-root <path> [--project-dir <path>]";

#[derive(Debug)]
struct HookError {
    code: i32,
    message: String,
}

type Result<T> = std::result::Result<T, HookError>;

impl HookError {
    fn operational(message: impl Into<String>) -> Self {
        Self {
            code: 1,
            message: message.into(),
        }
    }

    fn usage(message: impl Into<String>) -> Self {
        Self {
            code: 2,
            message: message.into(),
        }
    }
}

#[derive(Debug)]
struct Args {
    command: String,
    plugin_root: PathBuf,
    project_dir: PathBuf,
}

#[derive(Debug, Deserialize)]
struct RootConfig {
    hooks: HookConfig,
}

#[derive(Debug, Deserialize)]
struct HookConfig {
    title_prefix: String,
    #[serde(default = "default_session_template")]
    session_context: String,
    #[serde(default)]
    setup_context: Option<String>,
    #[serde(default)]
    command_warnings: Vec<CommandWarning>,
    #[serde(default)]
    path_warnings: Vec<PathWarning>,
    #[serde(default)]
    setup_complete_any: Vec<Vec<PathCheck>>,
}

fn default_session_template() -> String {
    "hooks/session-context.txt".into()
}

#[derive(Debug, Deserialize)]
struct CommandWarning {
    command: String,
    message: String,
}

#[derive(Debug, Deserialize)]
struct PathWarning {
    #[serde(flatten)]
    check: PathCheck,
    message: String,
}

#[derive(Debug, Deserialize)]
struct PathCheck {
    kind: CheckKind,
    path: String,
    #[serde(default)]
    base: CheckBase,
}

#[derive(Clone, Copy, Debug, Default, Deserialize)]
#[serde(rename_all = "lowercase")]
enum CheckBase {
    #[default]
    Project,
    State,
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum CheckKind {
    File,
    Dir,
}

/// Run a native hook and return a process-compatible exit status.
///
/// The caller passes arguments after `hook`. A leading literal `hook` is also
/// accepted so this function is convenient to integrate into either dispatcher.
pub fn main(args: &[OsString]) -> i32 {
    match run(args) {
        Ok(output) => match io::stdout().write_all(&output) {
            Ok(()) => 0,
            Err(error) => {
                let _ = writeln!(io::stderr(), "brk hook: failed to write stdout: {error}");
                1
            }
        },
        Err(error) => {
            let _ = writeln!(io::stderr(), "brk hook: {}", error.message);
            error.code
        }
    }
}

fn run(args: &[OsString]) -> Result<Vec<u8>> {
    let args = parse_args(args)?;
    let hook_config = load_hook_config(&args.plugin_root)?;
    match args.command.as_str() {
        "session-start" => session_start(&args, &hook_config),
        "title" => title(&args, &hook_config),
        _ => unreachable!(),
    }
}

fn session_start(args: &Args, config: &HookConfig) -> Result<Vec<u8>> {
    fs::create_dir_all(&args.project_dir).map_err(|error| {
        HookError::operational(format!("cannot create project directory: {error}"))
    })?;
    let snapshot = state::snapshot(&args.plugin_root, &args.project_dir, true)
        .map_err(state_error)?
        .expect("initializing snapshot is always present");
    let state_dir = snapshot.state_dir();
    let step = snapshot.step.number.to_string();
    let spine = snapshot
        .progress
        .get("spine_file")
        .and_then(Value::as_str)
        .unwrap_or("");
    let mode = snapshot
        .progress
        .get("mode")
        .and_then(Value::as_str)
        .ok_or_else(|| HookError::operational("progress field 'mode' is invalid"))?;
    let stepfile = args
        .plugin_root
        .join("curriculum")
        .join(format!("step-{:02}.md", snapshot.step.number));

    let mut warn = String::new();
    for item in &config.command_warnings {
        if !command_exists(&item.command) {
            warn.push_str(&item.message);
        }
    }
    for item in &config.path_warnings {
        if !check_path(&item.check, &snapshot.project_dir, &state_dir)? {
            warn.push_str(&item.message);
        }
    }

    let setup_done = config.setup_complete_any.iter().any(|alternative| {
        alternative
            .iter()
            .all(|check| check_path(check, &snapshot.project_dir, &state_dir).unwrap_or(false))
    });
    let setup_prefix = if !setup_done {
        match &config.setup_context {
            Some(path) => read_template(&args.plugin_root, path)?,
            None => String::new(),
        }
    } else {
        String::new()
    };

    let template = read_template(&args.plugin_root, &config.session_context)?;
    let values = [
        ("setup_prefix", setup_prefix.as_str()),
        ("step", step.as_str()),
        ("stepfile", path_text(&stepfile)?),
        ("spine", spine),
        ("mode", mode),
        ("ROOT", path_text(&args.plugin_root)?),
        ("DATA_DIR", path_text(&state_dir)?),
        ("warn", warn.as_str()),
    ];
    let context = interpolate(&template, &values)?;
    let title = format_title(config, snapshot.step.number, &snapshot.step.title);

    // Match the legacy cache semantics, but avoid exposing a partially written
    // value to a concurrent title hook.
    let cache = state_dir.join(".titled_step");
    let _ = state::write_atomic(&cache, step.as_bytes());

    serialize_envelope("SessionStart", Some(context), title)
}

fn title(args: &Args, config: &HookConfig) -> Result<Vec<u8>> {
    let snapshot =
        match state::snapshot(&args.plugin_root, &args.project_dir, false).map_err(state_error)? {
            Some(snapshot) => snapshot,
            None => return Ok(Vec::new()),
        };
    let step = snapshot.step.number.to_string();
    let cache = snapshot.state_dir().join(".titled_step");
    if fs::read(&cache).ok().as_deref() == Some(step.as_bytes()) {
        return Ok(Vec::new());
    }
    let _ = state::write_atomic(&cache, step.as_bytes());
    serialize_envelope(
        "UserPromptSubmit",
        None,
        format_title(config, snapshot.step.number, &snapshot.step.title),
    )
}

fn serialize_envelope(event: &str, context: Option<String>, title: String) -> Result<Vec<u8>> {
    let mut output = Map::new();
    output.insert("hookEventName".into(), Value::String(event.into()));
    if let Some(context) = context {
        output.insert("additionalContext".into(), Value::String(context));
    }
    output.insert("sessionTitle".into(), Value::String(title));
    let mut bytes =
        serde_json::to_vec(&json!({ "hookSpecificOutput": output })).map_err(|error| {
            HookError::operational(format!("cannot serialize hook output: {error}"))
        })?;
    bytes.push(b'\n');
    Ok(bytes)
}

fn format_title(config: &HookConfig, step: u64, name: &str) -> String {
    if name.is_empty() {
        format!("{} - Step {step}", config.title_prefix)
    } else {
        format!("{} - Step {step}: {name}", config.title_prefix)
    }
}

fn load_hook_config(plugin_root: &Path) -> Result<HookConfig> {
    let path = plugin_root.join("brk.json");
    let bytes = fs::read(&path).map_err(|error| {
        HookError::operational(format!("cannot read config '{}': {error}", path.display()))
    })?;
    let root: RootConfig = serde_json::from_slice(&bytes).map_err(|error| {
        HookError::operational(format!("invalid config '{}': {error}", path.display()))
    })?;
    validate_relative(&root.hooks.session_context, "session_context")?;
    if let Some(path) = &root.hooks.setup_context {
        validate_relative(path, "setup_context")?;
    }
    for warning in &root.hooks.command_warnings {
        if warning.command.is_empty() || warning.command.contains(['/', '\\']) {
            return Err(HookError::operational(
                "hook warning command must be a bare executable name",
            ));
        }
    }
    for check in root
        .hooks
        .path_warnings
        .iter()
        .map(|item| &item.check)
        .chain(root.hooks.setup_complete_any.iter().flatten())
    {
        validate_relative(&check.path, "hook check path")?;
    }
    Ok(root.hooks)
}

fn read_template(root: &Path, relative: &str) -> Result<String> {
    validate_relative(relative, "template path")?;
    let path =
        crate::paths::confined_relative_path(root, relative).map_err(HookError::operational)?;
    let text = fs::read_to_string(&path).map_err(|error| {
        HookError::operational(format!(
            "cannot read hook template '{}': {error}",
            path.display()
        ))
    })?;
    Ok(text.strip_suffix('\n').unwrap_or(&text).to_owned())
}

fn interpolate(template: &str, values: &[(&str, &str)]) -> Result<String> {
    let mut output = String::with_capacity(template.len());
    let mut rest = template;
    while let Some(start) = rest.find("${") {
        output.push_str(&rest[..start]);
        let placeholder = &rest[start + 2..];
        let end = placeholder
            .find('}')
            .ok_or_else(|| HookError::operational("unterminated hook template placeholder"))?;
        let name = &placeholder[..end];
        let value = values
            .iter()
            .find_map(|(candidate, value)| (*candidate == name).then_some(*value))
            .ok_or_else(|| {
                HookError::operational(format!("unknown hook template placeholder '${{{name}}}'"))
            })?;
        output.push_str(value);
        rest = &placeholder[end + 1..];
    }
    output.push_str(rest);
    Ok(output)
}

fn check_path(check: &PathCheck, project: &Path, state_dir: &Path) -> Result<bool> {
    validate_relative(&check.path, "hook check path")?;
    let base = match check.base {
        CheckBase::Project => project,
        CheckBase::State => state_dir,
    };
    let path = base.join(&check.path);
    Ok(match check.kind {
        CheckKind::File => path.is_file(),
        CheckKind::Dir => path.is_dir(),
    })
}

fn command_exists(command: &str) -> bool {
    let Some(path) = env::var_os("PATH") else {
        return false;
    };
    env::split_paths(&path).any(|directory| {
        let candidate = directory.join(command);
        if !candidate.is_file() {
            return false;
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::metadata(candidate)
                .map(|metadata| metadata.permissions().mode() & 0o111 != 0)
                .unwrap_or(false)
        }
        #[cfg(not(unix))]
        true
    })
}

fn validate_relative(value: &str, label: &str) -> Result<()> {
    if value.is_empty() {
        return Err(HookError::operational(format!(
            "{label} must be a relative path"
        )));
    }
    for component in Path::new(value).components() {
        match component {
            Component::Normal(_) | Component::CurDir => {}
            _ => {
                return Err(HookError::operational(format!(
                    "{label} must be a relative path"
                )));
            }
        }
    }
    Ok(())
}

fn path_text(path: &Path) -> Result<&str> {
    path.to_str()
        .ok_or_else(|| HookError::operational("hook paths must be valid UTF-8"))
}

fn state_error(error: state::AppError) -> HookError {
    HookError {
        code: error.code,
        message: error.message,
    }
}

fn parse_args(args: &[OsString]) -> Result<Args> {
    let mut index = usize::from(args.first().is_some_and(|arg| arg == OsStr::new("hook")));
    let command = args
        .get(index)
        .ok_or_else(|| HookError::usage(USAGE))?
        .to_str()
        .ok_or_else(|| HookError::usage("hook command must be valid UTF-8"))?
        .to_owned();
    if !matches!(command.as_str(), "session-start" | "title") {
        return Err(HookError::usage(format!(
            "unknown hook command '{command}'\n{USAGE}"
        )));
    }
    index += 1;
    let mut plugin_root = None;
    let mut project_dir = None;
    while index < args.len() {
        let flag = &args[index];
        if flag != "--plugin-root" && flag != "--project-dir" {
            return Err(HookError::usage(format!(
                "unknown option '{}'\n{USAGE}",
                flag.to_string_lossy()
            )));
        }
        let value = args
            .get(index + 1)
            .filter(|value| !value.is_empty() && !value.to_string_lossy().starts_with("--"))
            .ok_or_else(|| {
                HookError::usage(format!(
                    "{} requires a path\n{USAGE}",
                    flag.to_string_lossy()
                ))
            })?;
        let target = if flag == "--plugin-root" {
            &mut plugin_root
        } else {
            &mut project_dir
        };
        if target.replace(PathBuf::from(value)).is_some() {
            return Err(HookError::usage(format!(
                "{} may be specified only once\n{USAGE}",
                flag.to_string_lossy()
            )));
        }
        index += 2;
    }
    let plugin_root = plugin_root
        .or_else(|| {
            env::var_os("CLAUDE_PLUGIN_ROOT")
                .filter(|value| !value.is_empty())
                .map(PathBuf::from)
        })
        .ok_or_else(|| HookError::usage(format!("plugin root is required\n{USAGE}")))?;
    let project_dir = match project_dir.or_else(|| {
        env::var_os("CLAUDE_PROJECT_DIR")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
    }) {
        Some(path) => path,
        None => env::current_dir().map_err(|error| {
            HookError::operational(format!("cannot determine current directory: {error}"))
        })?,
    };
    Ok(Args {
        command,
        plugin_root,
        project_dir,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn interpolation_does_not_expand_values_or_execute_shell() {
        let value = "quoted \"value\" \\ ${step} $(touch never)";
        assert_eq!(
            interpolate("Step ${step}: ${mode}", &[("step", "2"), ("mode", value)]).unwrap(),
            format!("Step 2: {value}")
        );
    }

    #[test]
    fn unknown_and_unterminated_placeholders_fail_explicitly() {
        assert!(interpolate("${unknown}", &[]).is_err());
        assert!(interpolate("${step", &[("step", "1")]).is_err());
    }

    #[test]
    fn hook_envelope_escapes_context_and_title() {
        let context = "quote: \" newline:\n slash:\\";
        let title = "Step 1: \"title\"";
        let encoded =
            serialize_envelope("SessionStart", Some(context.into()), title.into()).unwrap();
        let decoded: Value = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded["hookSpecificOutput"]["additionalContext"], context);
        assert_eq!(decoded["hookSpecificOutput"]["sessionTitle"], title);
    }
}
