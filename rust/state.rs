//! Persistent per-project dojo state.
//!
//! `main` implements the `brk state` protocol. Configuration lives at
//! `<plugin-root>/brk.json`; curriculum rows live at
//! `<plugin-root>/curriculum/steps.tsv`.
//!
//! Schema 1 requires `state_dir` (one relative directory), `modality` (`code`
//! or `interview`), and `initial_mode` (`local-jailed` or `conversation`,
//! respectively). Optional `initial_spine` and `initial_extra` populate the
//! initial JSON without inferring missing fields. `initial_extra.tier = "none"`
//! explicitly enables the legacy C10K tier reset on advance; other extras are
//! never reset. Reserved progress fields cannot occur in `initial_extra`.
//!
//! All supported commands bootstrap missing state while holding a separate,
//! persistent `progress.lock`. Reads validate state without rewriting it;
//! `status` returns the original bytes. Mutations preserve unknown JSON fields.
//! Code TSV rows have four columns (step, title, spine, kind); interview rows
//! have three (step, title, kind). A spine of `-` is returned literally by
//! `spine`, but becomes `workspace/` in progress when advancing to that row.
//! Numeric lookups outside the curriculum return empty stdout, like awk.
//! Invalid usage returns 2; invalid data, I/O failures, and advancing past the
//! last row return 1. Advancing from the last row never changes existing state
//! (including `completed`); there is no synthetic step after the curriculum.

use serde::Deserialize;
use serde_json::{Map, Value};
use std::collections::BTreeMap;
use std::env;
use std::ffi::{OsStr, OsString};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Write};
use std::path::{Component, Path, PathBuf};
use tempfile::NamedTempFile;

const USAGE: &str = "usage: brk state --plugin-root <path> [--project-dir <path>] \
<get|spine|title|kind|mode|set-mode|advance|status> [value]";
const PROGRESS_FILE: &str = "progress.json";
const LOCK_FILE: &str = "progress.lock";
const STEPS_FILE: &str = "curriculum/steps.tsv";

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Modality {
    Code,
    Interview,
}

#[derive(Clone, Debug, Deserialize)]
pub struct Config {
    pub schema_version: u64,
    pub state_dir: String,
    pub modality: Modality,
    pub initial_mode: String,
    #[serde(default)]
    pub initial_spine: Option<String>,
    #[serde(default)]
    pub initial_extra: BTreeMap<String, Value>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Step {
    pub number: u64,
    pub title: String,
    pub spine: Option<String>,
    pub kind: String,
}

#[derive(Debug)]
pub(crate) struct AppError {
    pub(crate) code: i32,
    pub(crate) message: String,
}

#[derive(Clone, Debug)]
pub(crate) struct Snapshot {
    pub(crate) config: Config,
    pub(crate) step: Step,
    pub(crate) progress: Map<String, Value>,
    pub(crate) project_dir: PathBuf,
}

impl Snapshot {
    pub(crate) fn state_dir(&self) -> PathBuf {
        self.project_dir.join(&self.config.state_dir)
    }
}

impl AppError {
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

type AppResult<T> = Result<T, AppError>;

#[derive(Debug)]
struct ParsedArgs {
    plugin_root: PathBuf,
    project_dir: PathBuf,
    command: String,
    value: Option<OsString>,
}

/// Run the state subcommand and return a process-compatible exit status.
///
/// The caller passes arguments after `state`. For convenience, a leading
/// literal `state` is also accepted. Protocol output is written only to
/// stdout; diagnostics are written only to stderr.
pub fn main(args: &[OsString]) -> i32 {
    match run(args) {
        Ok(output) => match io::stdout().write_all(&output) {
            Ok(()) => 0,
            Err(error) => {
                let _ = writeln!(io::stderr(), "brk state: failed to write stdout: {error}");
                1
            }
        },
        Err(error) => {
            let _ = writeln!(io::stderr(), "brk state: {}", error.message);
            error.code
        }
    }
}

pub(crate) fn snapshot(
    plugin_root: &Path,
    project_dir: &Path,
    initialize: bool,
) -> AppResult<Option<Snapshot>> {
    let config = load_config(plugin_root)?;
    let progress_path = project_dir.join(&config.state_dir).join(PROGRESS_FILE);
    if !initialize && !progress_path.is_file() {
        return Ok(None);
    }
    let args = vec![
        OsString::from("--plugin-root"),
        plugin_root.as_os_str().to_owned(),
        OsString::from("--project-dir"),
        project_dir.as_os_str().to_owned(),
        OsString::from("status"),
    ];
    let raw = run(&args)?;
    let project_dir = project_dir.canonicalize().map_err(|error| {
        AppError::operational(format!("cannot resolve project directory: {error}"))
    })?;
    let steps = load_steps(plugin_root, config.modality)?;
    let progress = parse_progress(&raw, &progress_path, &steps, &config, &project_dir)?;
    let number = progress_step(&progress)?;
    let step = step_by_number(&steps, number)
        .cloned()
        .ok_or_else(|| AppError::operational("current step is not in curriculum"))?;
    Ok(Some(Snapshot {
        config,
        step,
        progress,
        project_dir,
    }))
}

pub(crate) fn write_atomic(path: &Path, bytes: &[u8]) -> AppResult<()> {
    atomic_write(path, bytes)
}

pub(crate) fn run(args: &[OsString]) -> AppResult<Vec<u8>> {
    let parsed = parse_args(args)?;
    let config = load_config(&parsed.plugin_root)?;
    if matches!(parsed.command.as_str(), "spine" | "kind") {
        require_code(config.modality, &parsed.command)?;
    }
    let steps = load_steps(&parsed.plugin_root, config.modality)?;
    fs::create_dir_all(&parsed.project_dir).map_err(|error| {
        AppError::operational(format!("cannot create project directory: {error}"))
    })?;
    let project_dir = parsed.project_dir.canonicalize().map_err(|error| {
        AppError::operational(format!("cannot resolve project directory: {error}"))
    })?;
    if let Some(spine) = &config.initial_spine {
        validate_project_target(&project_dir, spine)?;
    }
    for step in &steps {
        if let Some(spine) = &step.spine {
            validate_project_target(&project_dir, spine)?;
        }
    }
    let state_dir = project_dir.join(&config.state_dir);
    reject_symlink(&state_dir)?;
    fs::create_dir_all(&state_dir).map_err(|error| {
        AppError::operational(format!(
            "cannot create state directory '{}': {error}",
            state_dir.display()
        ))
    })?;

    let lock_path = state_dir.join(LOCK_FILE);
    reject_symlink(&lock_path)?;
    let lock = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(&lock_path)
        .map_err(|error| {
            AppError::operational(format!(
                "cannot open state lock '{}': {error}",
                lock_path.display()
            ))
        })?;
    lock.lock().map_err(|error| {
        AppError::operational(format!(
            "cannot lock state '{}': {error}",
            lock_path.display()
        ))
    })?;

    let progress_path = state_dir.join(PROGRESS_FILE);
    reject_symlink(&progress_path)?;
    let mut raw = match fs::read(&progress_path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == io::ErrorKind::NotFound => {
            let initial = initial_progress(&config);
            let bytes = serialize_progress(&initial)?;
            // Validate before the first write just as for subsequent mutations.
            parse_progress(&bytes, &progress_path, &steps, &config, &project_dir)?;
            atomic_write(&progress_path, &bytes)?;
            bytes
        }
        Err(error) => {
            return Err(AppError::operational(format!(
                "cannot read progress '{}': {error}",
                progress_path.display()
            )));
        }
    };

    let mut progress = parse_progress(&raw, &progress_path, &steps, &config, &project_dir)?;
    let current_step = progress_step(&progress)?;

    let output = match parsed.command.as_str() {
        "get" => line(current_step),
        "mode" => line(progress_string(&progress, "mode")?),
        "title" => {
            let requested = optional_step(parsed.value.as_deref(), current_step)?;
            lookup_line(step_by_number(&steps, requested).map(|step| step.title.as_str()))
        }
        "spine" => {
            require_code(config.modality, "spine")?;
            let requested = optional_step(parsed.value.as_deref(), current_step)?;
            lookup_line(
                step_by_number(&steps, requested).map(|step| step.spine.as_deref().unwrap_or("-")),
            )
        }
        "kind" => {
            require_code(config.modality, "kind")?;
            let requested = optional_step(parsed.value.as_deref(), current_step)?;
            lookup_line(step_by_number(&steps, requested).map(|step| step.kind.as_str()))
        }
        "status" => raw,
        "set-mode" => {
            let mode = match parsed.value {
                Some(value) => os_to_string(&value, "mode")?,
                None => config.initial_mode.clone(),
            };
            progress.insert("mode".into(), Value::String(mode));
            raw = serialize_progress(&progress)?;
            atomic_write(&progress_path, &raw)?;
            Vec::new()
        }
        "advance" => {
            let next = current_step.checked_add(1).ok_or_else(|| {
                AppError::operational("current step cannot be advanced because it overflows")
            })?;
            let next_step = step_by_number(&steps, next).ok_or_else(|| {
                AppError::operational(format!("cannot advance beyond final step {}", steps.len()))
            })?;

            let completed = progress
                .get_mut("completed")
                .and_then(Value::as_array_mut)
                .ok_or_else(|| AppError::operational("progress field 'completed' is invalid"))?;
            completed.push(Value::from(current_step));
            progress.insert("step".into(), Value::from(next));

            if config.modality == Modality::Code {
                let spine = next_step.spine.as_deref().unwrap_or("workspace/");
                validate_project_target(&project_dir, spine)?;
                progress.insert("spine_file".into(), Value::String(spine.to_owned()));
            }
            if matches!(config.initial_extra.get("tier"), Some(Value::String(value)) if value == "none")
            {
                progress.insert("tier".into(), Value::String("none".into()));
            }

            raw = serialize_progress(&progress)?;
            atomic_write(&progress_path, &raw)?;
            line(format!("Advanced to step {next} ({})", next_step.title))
        }
        _ => unreachable!("commands are validated by parse_args"),
    };
    Ok(output)
}

fn parse_args(args: &[OsString]) -> AppResult<ParsedArgs> {
    parse_args_in(
        args,
        env::var_os("CLAUDE_PLUGIN_ROOT"),
        env::var_os("CLAUDE_PROJECT_DIR"),
        env::current_dir,
    )
}

// Inject environment and cwd for deterministic tests without process-global
// environment mutation (which is unsafe with concurrent tests in edition 2024).
fn parse_args_in(
    args: &[OsString],
    env_root: Option<OsString>,
    env_project: Option<OsString>,
    cwd: impl FnOnce() -> io::Result<PathBuf>,
) -> AppResult<ParsedArgs> {
    let mut index = usize::from(args.first().is_some_and(|arg| arg == "state"));
    let mut plugin_root = None;
    let mut project_dir = None;

    while let Some(argument) = args.get(index) {
        if argument == "--plugin-root" || argument == "--project-dir" {
            let flag = argument.clone();
            let value = args.get(index + 1).cloned().ok_or_else(|| {
                AppError::usage(format!(
                    "{} requires a path\n{USAGE}",
                    flag.to_string_lossy()
                ))
            })?;
            if value.is_empty() || value.to_string_lossy().starts_with("--") {
                return Err(AppError::usage(format!(
                    "{} requires a non-empty path\n{USAGE}",
                    flag.to_string_lossy()
                )));
            }
            if flag == "--plugin-root" {
                if plugin_root.replace(PathBuf::from(value)).is_some() {
                    return Err(AppError::usage(format!(
                        "--plugin-root may be specified only once\n{USAGE}"
                    )));
                }
            } else if project_dir.replace(PathBuf::from(value)).is_some() {
                return Err(AppError::usage(format!(
                    "--project-dir may be specified only once\n{USAGE}"
                )));
            }
            index += 2;
            continue;
        }
        if argument.to_string_lossy().starts_with('-') {
            return Err(AppError::usage(format!(
                "unknown option '{}'\n{USAGE}",
                argument.to_string_lossy()
            )));
        }
        break;
    }

    let plugin_root = plugin_root
        .or_else(|| {
            env_root
                .filter(|value| !value.is_empty())
                .map(PathBuf::from)
        })
        .ok_or_else(|| {
            AppError::usage(format!(
                "plugin root is required (--plugin-root or CLAUDE_PLUGIN_ROOT)\n{USAGE}"
            ))
        })?;
    let project_dir = match project_dir.or_else(|| {
        env_project
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
    }) {
        Some(path) => path,
        None => cwd().map_err(|error| {
            AppError::operational(format!("cannot determine current directory: {error}"))
        })?,
    };

    let command_os = args.get(index).ok_or_else(|| AppError::usage(USAGE))?;
    let command = os_to_string(command_os, "command")?;
    let value = args.get(index + 1).cloned();
    if args.len() > index + 2 {
        return Err(AppError::usage(format!("too many arguments\n{USAGE}")));
    }

    let valid = [
        "get", "spine", "title", "kind", "mode", "set-mode", "advance", "status",
    ];
    if !valid.contains(&command.as_str()) {
        return Err(AppError::usage(format!(
            "unknown state command '{command}'\n{USAGE}"
        )));
    }
    let accepts_value = matches!(command.as_str(), "spine" | "title" | "kind" | "set-mode");
    if value.is_some() && !accepts_value {
        return Err(AppError::usage(format!(
            "command '{command}' does not accept a value\n{USAGE}"
        )));
    }

    Ok(ParsedArgs {
        plugin_root,
        project_dir,
        command,
        value,
    })
}

fn load_config(plugin_root: &Path) -> AppResult<Config> {
    let path = plugin_root.join("brk.json");
    let bytes = fs::read(&path).map_err(|error| {
        if error.kind() == io::ErrorKind::NotFound {
            AppError::operational(format!(
                "plugin state configuration is missing: '{}'",
                path.display()
            ))
        } else {
            AppError::operational(format!("cannot read config '{}': {error}", path.display()))
        }
    })?;
    let config: Config = serde_json::from_slice(&bytes).map_err(|error| {
        AppError::operational(format!("invalid config '{}': {error}", path.display()))
    })?;
    validate_config(&config, &path)?;
    Ok(config)
}

fn validate_config(config: &Config, path: &Path) -> AppResult<()> {
    if config.schema_version != 1 {
        return Err(AppError::operational(format!(
            "unsupported schema_version {} in '{}' (expected 1)",
            config.schema_version,
            path.display()
        )));
    }
    if !is_single_relative_directory(&config.state_dir) {
        return Err(AppError::operational(format!(
            "state_dir in '{}' must be one relative directory name",
            path.display()
        )));
    }
    let expected_mode = match config.modality {
        Modality::Code => "local-jailed",
        Modality::Interview => "conversation",
    };
    if config.initial_mode != expected_mode {
        return Err(AppError::operational(format!(
            "initial_mode in '{}' must be '{expected_mode}' for {:?} modality",
            path.display(),
            config.modality
        )));
    }
    if let Some(spine) = &config.initial_spine {
        if config.modality == Modality::Interview {
            return Err(AppError::operational(
                "interview configuration must not set initial_spine",
            ));
        }
        validate_relative_project_path(spine, "initial_spine")?;
    }
    for reserved in ["step", "completed", "mode", "spine_file"] {
        if config.initial_extra.contains_key(reserved) {
            return Err(AppError::operational(format!(
                "initial_extra in '{}' must not redefine reserved field '{reserved}'",
                path.display()
            )));
        }
    }
    Ok(())
}

fn is_single_relative_directory(value: &str) -> bool {
    if value.is_empty() || value.contains(['/', '\\', ':']) || value.chars().any(char::is_control) {
        return false;
    }
    let mut components = Path::new(value).components();
    matches!(components.next(), Some(Component::Normal(_))) && components.next().is_none()
}

fn validate_relative_project_path(value: &str, field: &str) -> AppResult<()> {
    if value.is_empty() || value.contains(['\\', ':']) || value.chars().any(char::is_control) {
        return Err(AppError::operational(format!(
            "{field} must be a non-empty relative project path"
        )));
    }
    let mut found_normal = false;
    for component in Path::new(value).components() {
        match component {
            Component::Normal(_) => found_normal = true,
            Component::CurDir => {}
            Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                return Err(AppError::operational(format!(
                    "{field} must not escape the project directory: '{value}'"
                )));
            }
        }
    }
    if !found_normal {
        return Err(AppError::operational(format!(
            "{field} must be a non-empty relative project path"
        )));
    }
    Ok(())
}

// Check existing path components as well as lexical traversal. Spine files do
// not have to exist yet. Existing symlinks must resolve inside the project;
// dangling links are errors rather than being treated as missing files.
fn validate_project_target(project: &Path, relative: &str) -> AppResult<()> {
    validate_relative_project_path(relative, "spine path")?;
    let mut candidate = project.to_owned();
    for component in Path::new(relative).components() {
        candidate.push(component);
        match fs::symlink_metadata(&candidate) {
            Ok(_) => {
                let resolved = candidate.canonicalize().map_err(|error| {
                    AppError::operational(format!(
                        "cannot resolve spine path '{}': {error}",
                        candidate.display()
                    ))
                })?;
                if !resolved.starts_with(project) {
                    return Err(AppError::operational(format!(
                        "spine path must not escape the project directory: '{relative}'"
                    )));
                }
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => break,
            Err(error) => {
                return Err(AppError::operational(format!(
                    "cannot inspect spine path '{}': {error}",
                    candidate.display()
                )));
            }
        }
    }
    Ok(())
}

// A stable lock inode must not be replaceable through a preexisting symlink.
// Also avoid replacing a dangling progress symlink during bootstrap.
fn reject_symlink(path: &Path) -> AppResult<()> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(AppError::operational(format!(
            "state path must not be a symbolic link: '{}'",
            path.display()
        ))),
        Ok(_) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(AppError::operational(format!(
            "cannot inspect state path '{}': {error}",
            path.display()
        ))),
    }
}

fn load_steps(plugin_root: &Path, modality: Modality) -> AppResult<Vec<Step>> {
    let path = plugin_root.join(STEPS_FILE);
    let text = fs::read_to_string(&path).map_err(|error| {
        AppError::operational(format!("cannot read steps '{}': {error}", path.display()))
    })?;
    let expected_columns = if modality == Modality::Code { 4 } else { 3 };
    let mut steps = Vec::new();

    for (line_index, original_line) in text.lines().enumerate() {
        let line_number = line_index + 1;
        let line = original_line.strip_suffix('\r').unwrap_or(original_line);
        if line.is_empty() {
            return Err(AppError::operational(format!(
                "invalid empty row at '{}:{line_number}'",
                path.display()
            )));
        }
        let columns: Vec<&str> = line.split('\t').collect();
        if columns.len() != expected_columns {
            return Err(AppError::operational(format!(
                "invalid row at '{}:{line_number}': expected {expected_columns} tab-separated columns, found {}",
                path.display(),
                columns.len()
            )));
        }
        let number = columns[0].parse::<u64>().map_err(|_| {
            AppError::operational(format!(
                "invalid step number at '{}:{line_number}'",
                path.display()
            ))
        })?;
        let expected_number = steps.len() as u64 + 1;
        if number != expected_number {
            return Err(AppError::operational(format!(
                "steps in '{}' must be unique, ordered, and contiguous: expected {expected_number}, found {number}",
                path.display()
            )));
        }
        if columns[1].trim().is_empty() || columns[1].chars().any(char::is_control) {
            return Err(AppError::operational(format!(
                "step title must not be empty at '{}:{line_number}'",
                path.display()
            )));
        }

        let (spine, kind) = if modality == Modality::Code {
            let spine = if columns[2] == "-" {
                None
            } else {
                validate_relative_project_path(columns[2], "step spine")?;
                Some(columns[2].to_owned())
            };
            if columns[3].is_empty() {
                return Err(AppError::operational(format!(
                    "step kind must not be empty at '{}:{line_number}'",
                    path.display()
                )));
            }
            (spine, columns[3].to_owned())
        } else {
            if columns[2].is_empty() {
                return Err(AppError::operational(format!(
                    "step kind must not be empty at '{}:{line_number}'",
                    path.display()
                )));
            }
            (None, columns[2].to_owned())
        };

        steps.push(Step {
            number,
            title: columns[1].to_owned(),
            spine,
            kind,
        });
    }

    if steps.is_empty() {
        return Err(AppError::operational(format!(
            "steps file '{}' must contain at least one row",
            path.display()
        )));
    }
    Ok(steps)
}

fn initial_progress(config: &Config) -> Map<String, Value> {
    let mut progress = Map::new();
    progress.insert("step".into(), Value::from(1));
    progress.insert("completed".into(), Value::Array(Vec::new()));
    if let Some(spine) = &config.initial_spine {
        progress.insert("spine_file".into(), Value::String(spine.clone()));
    }
    for (key, value) in &config.initial_extra {
        progress.insert(key.clone(), value.clone());
    }
    progress.insert("mode".into(), Value::String(config.initial_mode.clone()));
    progress
}

fn parse_progress(
    raw: &[u8],
    path: &Path,
    steps: &[Step],
    config: &Config,
    project: &Path,
) -> AppResult<Map<String, Value>> {
    let value: Value = serde_json::from_slice(raw).map_err(|error| {
        AppError::operational(format!(
            "invalid progress JSON in '{}': {error}; file was not changed",
            path.display()
        ))
    })?;
    let object = value.as_object().ok_or_else(|| {
        AppError::operational(format!(
            "invalid progress in '{}': root must be a JSON object; file was not changed",
            path.display()
        ))
    })?;

    let step = object.get("step").and_then(Value::as_u64).ok_or_else(|| {
        AppError::operational(format!(
            "invalid progress field 'step' in '{}'; file was not changed",
            path.display()
        ))
    })?;
    if step == 0 || step > steps.len() as u64 {
        return Err(AppError::operational(format!(
            "invalid progress field 'step' in '{}': {step} is outside 1..={}; file was not changed",
            path.display(),
            steps.len()
        )));
    }

    let completed = object
        .get("completed")
        .and_then(Value::as_array)
        .ok_or_else(|| {
            AppError::operational(format!(
                "invalid progress field 'completed' in '{}'; file was not changed",
                path.display()
            ))
        })?;
    for value in completed {
        let completed_step = value.as_u64().ok_or_else(|| {
            AppError::operational(format!(
                "invalid progress field 'completed' in '{}': entries must be step numbers; file was not changed",
                path.display()
            ))
        })?;
        if completed_step == 0 || completed_step > steps.len() as u64 {
            return Err(AppError::operational(format!(
                "invalid progress field 'completed' in '{}': {completed_step} is outside 1..={}; file was not changed",
                path.display(),
                steps.len()
            )));
        }
    }

    if object.get("mode").and_then(Value::as_str).is_none() {
        return Err(AppError::operational(format!(
            "invalid progress field 'mode' in '{}'; file was not changed",
            path.display()
        )));
    }
    if let Some(spine) = object.get("spine_file") {
        let spine = spine.as_str().ok_or_else(|| {
            AppError::operational(format!(
                "invalid progress field 'spine_file' in '{}'; file was not changed",
                path.display()
            ))
        })?;
        validate_project_target(project, spine)?;
    } else if config.initial_spine.is_some() {
        return Err(AppError::operational(format!(
            "missing progress field 'spine_file' in '{}'; file was not changed",
            path.display()
        )));
    }
    if config.initial_extra.get("tier").and_then(Value::as_str) == Some("none")
        && object.get("tier").and_then(Value::as_str).is_none()
    {
        return Err(AppError::operational(format!(
            "invalid progress field 'tier' in '{}'; file was not changed",
            path.display()
        )));
    }

    Ok(object.clone())
}

fn serialize_progress(progress: &Map<String, Value>) -> AppResult<Vec<u8>> {
    let mut bytes = serde_json::to_vec(&Value::Object(progress.clone()))
        .map_err(|error| AppError::operational(format!("cannot serialize progress: {error}")))?;
    bytes.push(b'\n');
    Ok(bytes)
}

fn atomic_write(path: &Path, bytes: &[u8]) -> AppResult<()> {
    let parent = path.parent().ok_or_else(|| {
        AppError::operational(format!("progress path '{}' has no parent", path.display()))
    })?;
    let mut temporary = NamedTempFile::new_in(parent).map_err(|error| {
        AppError::operational(format!(
            "cannot create temporary progress file in '{}': {error}",
            parent.display()
        ))
    })?;
    temporary.write_all(bytes).map_err(|error| {
        AppError::operational(format!("cannot write temporary progress file: {error}"))
    })?;
    temporary.flush().map_err(|error| {
        AppError::operational(format!("cannot flush temporary progress file: {error}"))
    })?;
    temporary.as_file().sync_all().map_err(|error| {
        AppError::operational(format!("cannot sync temporary progress file: {error}"))
    })?;
    temporary.persist(path).map_err(|error| {
        AppError::operational(format!(
            "cannot atomically persist progress '{}': {}",
            path.display(),
            error.error
        ))
    })?;
    File::open(parent)
        .and_then(|directory| directory.sync_all())
        .map_err(|error| {
            AppError::operational(format!(
                "cannot sync state directory '{}': {error}",
                parent.display()
            ))
        })?;
    Ok(())
}

fn require_code(modality: Modality, command: &str) -> AppResult<()> {
    if modality == Modality::Interview {
        Err(AppError::usage(format!(
            "command '{command}' is not available for interview dojos"
        )))
    } else {
        Ok(())
    }
}

fn optional_step(value: Option<&OsStr>, current: u64) -> AppResult<u64> {
    match value {
        None => Ok(current),
        Some(value) => os_to_string(value, "step")?.parse::<u64>().map_err(|_| {
            AppError::usage(format!(
                "step must be a non-negative integer, got '{}'",
                value.to_string_lossy()
            ))
        }),
    }
}

fn os_to_string(value: &OsStr, label: &str) -> AppResult<String> {
    value
        .to_str()
        .map(str::to_owned)
        .ok_or_else(|| AppError::usage(format!("{label} must be valid UTF-8")))
}

fn progress_step(progress: &Map<String, Value>) -> AppResult<u64> {
    progress
        .get("step")
        .and_then(Value::as_u64)
        .ok_or_else(|| AppError::operational("progress field 'step' is invalid"))
}

fn progress_string<'a>(progress: &'a Map<String, Value>, field: &str) -> AppResult<&'a str> {
    progress
        .get(field)
        .and_then(Value::as_str)
        .ok_or_else(|| AppError::operational(format!("progress field '{field}' is invalid")))
}

fn step_by_number(steps: &[Step], number: u64) -> Option<&Step> {
    number
        .checked_sub(1)
        .and_then(|index| usize::try_from(index).ok())
        .and_then(|index| steps.get(index))
}

fn lookup_line(value: Option<&str>) -> Vec<u8> {
    value.map(line).unwrap_or_default()
}

fn line(value: impl std::fmt::Display) -> Vec<u8> {
    format!("{value}\n").into_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Barrier};
    use std::thread;
    use tempfile::TempDir;

    fn setup(modality: Modality, extra: &str, rows: &str) -> (TempDir, TempDir) {
        let plugin = tempfile::tempdir().unwrap();
        let project = tempfile::tempdir().unwrap();
        fs::create_dir(plugin.path().join("curriculum")).unwrap();
        let (modality, mode, spine) = match modality {
            Modality::Code => (
                "code",
                "local-jailed",
                r#", "initial_spine":"workspace/one.rb""#,
            ),
            Modality::Interview => ("interview", "conversation", ""),
        };
        fs::write(
            plugin.path().join("brk.json"),
            format!(
                r#"{{"schema_version":1,"state_dir":".test","modality":"{modality}","initial_mode":"{mode}"{spine}{extra}}}"#
            ),
        )
        .unwrap();
        fs::write(plugin.path().join(STEPS_FILE), rows).unwrap();
        (plugin, project)
    }

    fn args(plugin: &Path, project: &Path, tail: &[&str]) -> Vec<OsString> {
        let mut result = vec![
            OsString::from("--plugin-root"),
            plugin.as_os_str().to_owned(),
            OsString::from("--project-dir"),
            project.as_os_str().to_owned(),
        ];
        result.extend(tail.iter().map(OsString::from));
        result
    }

    fn invoke(plugin: &Path, project: &Path, tail: &[&str]) -> AppResult<Vec<u8>> {
        run(&args(plugin, project, tail))
    }

    fn progress(project: &Path) -> Value {
        serde_json::from_slice(&fs::read(project.join(".test/progress.json")).unwrap()).unwrap()
    }

    #[test]
    fn parses_code_and_interview_tsv_variants() {
        let (plugin, project) = setup(
            Modality::Code,
            "",
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\t-\tcheck\n",
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["spine", "2"]).unwrap(),
            b"-\n"
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["kind", "2"]).unwrap(),
            b"check\n"
        );

        let (plugin, project) = setup(
            Modality::Interview,
            "",
            "1\tScope\tinterview\n2\tDesign\tdesign\n",
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["title", "2"]).unwrap(),
            b"Design\n"
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["spine"])
                .unwrap_err()
                .code,
            2
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["kind"])
                .unwrap_err()
                .code,
            2
        );
    }

    #[test]
    fn preserves_legacy_mode_and_unknown_extra_and_resets_c10k_tier() {
        let (plugin, project) = setup(
            Modality::Code,
            r#", "initial_extra":{"tier":"none"}"#,
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\tworkspace/two.rb\tbuild\n",
        );
        invoke(plugin.path(), project.path(), &["get"]).unwrap();
        let path = project.path().join(".test/progress.json");
        fs::write(
            &path,
            r#"{"step":1,"completed":[],"spine_file":"workspace/one.rb","mode":"legacy-backend","tier":"large","future":{"kept":true}}"#,
        )
        .unwrap();

        invoke(
            plugin.path(),
            project.path(),
            &["set-mode", "another-legacy-mode"],
        )
        .unwrap();
        invoke(plugin.path(), project.path(), &["advance"]).unwrap();
        let value = progress(project.path());
        assert_eq!(value["mode"], "another-legacy-mode");
        assert_eq!(value["tier"], "none");
        assert_eq!(value["future"]["kept"], true);
        assert_eq!(value["completed"], serde_json::json!([1]));
    }

    #[test]
    fn c10k_set_mode_keeps_tier_until_advance_and_does_not_reset_other_extras() {
        let (plugin, project) = setup(
            Modality::Code,
            r#", "initial_extra":{"tier":"none","score":0}"#,
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\tworkspace/two.rb\tbuild\n",
        );
        invoke(plugin.path(), project.path(), &["get"]).unwrap();
        let mut state = progress(project.path());
        state["tier"] = serde_json::json!("bronze");
        state["score"] = serde_json::json!(99);
        fs::write(
            project.path().join(".test/progress.json"),
            serde_json::to_vec(&state).unwrap(),
        )
        .unwrap();
        invoke(plugin.path(), project.path(), &["set-mode", "custom"]).unwrap();
        assert_eq!(progress(project.path())["tier"], "bronze");
        invoke(plugin.path(), project.path(), &["advance"]).unwrap();
        let state = progress(project.path());
        assert_eq!(state["tier"], "none");
        assert_eq!(state["score"], 99);
    }

    #[test]
    fn malformed_json_is_never_overwritten() {
        let (plugin, project) = setup(
            Modality::Code,
            "",
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\tworkspace/two.rb\tbuild\n",
        );
        let state = project.path().join(".test");
        fs::create_dir(&state).unwrap();
        let path = state.join(PROGRESS_FILE);
        let malformed = b"{ definitely not JSON\n";
        fs::write(&path, malformed).unwrap();

        assert!(invoke(plugin.path(), project.path(), &["set-mode", "x"]).is_err());
        assert_eq!(fs::read(path).unwrap(), malformed);
    }

    #[test]
    fn final_step_advance_errors_without_changing_state() {
        let (plugin, project) = setup(
            Modality::Interview,
            "",
            "1\tScope\tinterview\n2\tDesign\tdesign\n",
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["advance"]).unwrap(),
            b"Advanced to step 2 (Design)\n"
        );
        let path = project.path().join(".test/progress.json");
        let before = fs::read(&path).unwrap();
        let error = invoke(plugin.path(), project.path(), &["advance"]).unwrap_err();
        assert!(error.message.contains("final step"));
        assert_eq!(fs::read(path).unwrap(), before);
    }

    #[test]
    fn status_preserves_existing_valid_bytes() {
        let (plugin, project) = setup(Modality::Interview, "", "1\tScope\tinterview\n");
        let state = project.path().join(".test");
        fs::create_dir(&state).unwrap();
        let raw = b"{ \"step\": 1, \"completed\": [], \"mode\": \"old\", \"x\": 3 }";
        fs::write(state.join(PROGRESS_FILE), raw).unwrap();
        assert_eq!(
            invoke(plugin.path(), project.path(), &["status"]).unwrap(),
            raw
        );
    }

    #[test]
    fn concurrent_advances_are_serialized_and_atomic() {
        let (plugin, project) = setup(
            Modality::Code,
            "",
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\tworkspace/two.rb\tbuild\n3\tThree\tworkspace/three.rb\tbuild\n",
        );
        let plugin = Arc::new(plugin);
        let project = Arc::new(project);
        let barrier = Arc::new(Barrier::new(3));
        let mut handles = Vec::new();
        for _ in 0..2 {
            let plugin = Arc::clone(&plugin);
            let project = Arc::clone(&project);
            let barrier = Arc::clone(&barrier);
            handles.push(thread::spawn(move || {
                barrier.wait();
                invoke(plugin.path(), project.path(), &["advance"])
            }));
        }
        barrier.wait();
        for handle in handles {
            handle.join().unwrap().unwrap();
        }
        let value = progress(project.path());
        assert_eq!(value["step"], 3);
        assert_eq!(value["completed"], serde_json::json!([1, 2]));
        assert_eq!(value["spine_file"], "workspace/three.rb");
    }

    #[test]
    fn initial_json_matches_both_modalities_without_inference() {
        let (plugin, project) = setup(Modality::Code, "", "1\tOne\tworkspace/one.rb\tbuild\n");
        assert_eq!(
            invoke(plugin.path(), project.path(), &["get"]).unwrap(),
            b"1\n"
        );
        assert_eq!(
            progress(project.path()),
            serde_json::json!({
                "step": 1, "completed": [], "mode": "local-jailed", "spine_file": "workspace/one.rb"
            })
        );
        let config_path = plugin.path().join("brk.json");
        let mut config: Value = serde_json::from_slice(&fs::read(&config_path).unwrap()).unwrap();
        config.as_object_mut().unwrap().remove("initial_spine");
        fs::write(config_path, serde_json::to_vec(&config).unwrap()).unwrap();
        let fresh = tempfile::tempdir().unwrap();
        invoke(plugin.path(), fresh.path(), &["status"]).unwrap();
        assert!(progress(fresh.path()).get("spine_file").is_none());

        let (plugin, project) = setup(Modality::Interview, "", "1\tScope\tinterview\n");
        invoke(plugin.path(), project.path(), &["status"]).unwrap();
        assert_eq!(
            progress(project.path()),
            serde_json::json!({
                "step": 1, "completed": [], "mode": "conversation"
            })
        );
    }

    #[test]
    fn interview_accepts_arbitrary_modes_and_preserves_all_extras() {
        let (plugin, project) = setup(
            Modality::Interview,
            r#", "initial_extra":{"tier":{"name":"gold"},"future":{"values":[true,null,42]}}"#,
            "1\tScope\tinterview\n2\tDesign\tdesign\n",
        );
        let mode = "legacy \"mode\" \\ newline\n日本語";
        assert!(
            invoke(plugin.path(), project.path(), &["set-mode", mode])
                .unwrap()
                .is_empty()
        );
        assert_eq!(
            invoke(plugin.path(), project.path(), &["mode"]).unwrap(),
            line(mode)
        );
        invoke(plugin.path(), project.path(), &["advance"]).unwrap();
        let state = progress(project.path());
        assert_eq!(state["mode"], mode);
        assert_eq!(state["tier"], serde_json::json!({"name": "gold"}));
        assert_eq!(
            state["future"],
            serde_json::json!({"values": [true, null, 42]})
        );
        assert!(state.get("spine_file").is_none());
        invoke(plugin.path(), project.path(), &["set-mode"]).unwrap();
        assert_eq!(progress(project.path())["mode"], "conversation");
        invoke(plugin.path(), project.path(), &["set-mode", ""]).unwrap();
        assert_eq!(progress(project.path())["mode"], "");
    }

    #[test]
    fn missing_lookup_is_empty_and_dash_advance_uses_workspace() {
        let (plugin, project) = setup(
            Modality::Code,
            "",
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\t-\tcheck\n",
        );
        for command in ["title", "spine", "kind"] {
            assert!(
                invoke(plugin.path(), project.path(), &[command, "99"])
                    .unwrap()
                    .is_empty()
            );
        }
        invoke(plugin.path(), project.path(), &["advance"]).unwrap();
        assert_eq!(progress(project.path())["spine_file"], "workspace/");
        assert_eq!(
            invoke(plugin.path(), project.path(), &["spine"]).unwrap(),
            b"-\n"
        );
    }

    #[test]
    fn invalid_progress_fields_never_overwrite_existing_bytes() {
        let (plugin, project) = setup(
            Modality::Code,
            r#", "initial_extra":{"tier":"none"}"#,
            "1\tOne\tworkspace/one.rb\tbuild\n2\tTwo\tworkspace/two.rb\tbuild\n",
        );
        invoke(plugin.path(), project.path(), &["get"]).unwrap();
        let valid = progress(project.path());
        let path = project.path().join(".test/progress.json");
        let invalid = [
            ("step", serde_json::json!("1")),
            ("step", serde_json::json!(0)),
            ("step", serde_json::json!(3)),
            ("step", serde_json::json!(1.5)),
            ("completed", serde_json::json!(null)),
            ("completed", serde_json::json!(["1"])),
            ("completed", serde_json::json!([0])),
            ("completed", serde_json::json!([3])),
            ("mode", serde_json::json!(false)),
            ("spine_file", serde_json::json!(null)),
            ("spine_file", serde_json::json!("../outside")),
            ("tier", serde_json::json!(3)),
        ];
        for (field, value) in invalid {
            let mut state = valid.clone();
            state[field] = value;
            let raw = serde_json::to_vec_pretty(&state).unwrap();
            fs::write(&path, &raw).unwrap();
            for command in ["get", "status", "advance", "set-mode"] {
                assert!(
                    invoke(plugin.path(), project.path(), &[command]).is_err(),
                    "{field}: {command}"
                );
                assert_eq!(fs::read(&path).unwrap(), raw);
            }
        }
        for field in ["step", "completed", "mode", "spine_file", "tier"] {
            let mut state = valid.clone();
            state.as_object_mut().unwrap().remove(field);
            let raw = serde_json::to_vec(&state).unwrap();
            fs::write(&path, &raw).unwrap();
            assert!(invoke(plugin.path(), project.path(), &["advance"]).is_err());
            assert_eq!(fs::read(&path).unwrap(), raw);
        }
    }

    #[test]
    fn invalid_config_does_not_create_state() {
        let (plugin, project) = setup(Modality::Code, "", "1\tOne\tworkspace/one.rb\tbuild\n");
        let config_path = plugin.path().join("brk.json");
        let valid: Value = serde_json::from_slice(&fs::read(&config_path).unwrap()).unwrap();
        for dir in [
            "",
            ".",
            "..",
            "../outside",
            "/absolute",
            "a/b",
            "a\\b",
            "C:",
            "name\0",
        ] {
            let mut config = valid.clone();
            config["state_dir"] = Value::String(dir.to_owned());
            fs::write(&config_path, serde_json::to_vec(&config).unwrap()).unwrap();
            assert!(
                invoke(plugin.path(), project.path(), &["get"]).is_err(),
                "{dir:?}"
            );
        }
        for (field, value) in [
            ("schema_version", serde_json::json!(2)),
            ("modality", serde_json::json!("guess")),
            ("initial_mode", serde_json::json!(false)),
            ("initial_spine", serde_json::json!("/escape")),
            ("initial_extra", serde_json::json!({"step": 2})),
        ] {
            let mut config = valid.clone();
            config[field] = value;
            fs::write(&config_path, serde_json::to_vec(&config).unwrap()).unwrap();
            assert!(invoke(plugin.path(), project.path(), &["get"]).is_err());
        }
        fs::remove_file(&config_path).unwrap();
        let error = invoke(plugin.path(), project.path(), &["get"]).unwrap_err();
        assert_eq!(error.code, 1);
        assert!(error.message.contains("configuration is missing"));
        assert_eq!(fs::read_dir(project.path()).unwrap().count(), 0);
    }

    #[test]
    fn tsv_rejects_duplicates_wrong_width_and_empty_titles_and_accepts_crlf() {
        let (plugin, project) = setup(Modality::Code, "", "1\tOne\tworkspace/one.rb\tbuild\n");
        for rows in [
            "1\tOne\t-\tbuild\n1\tDuplicate\t-\tbuild\n",
            "2\tTwo\t-\tbuild\n1\tOne\t-\tbuild\n",
            "1\tOne\tbuild\n",
            "1\t\t-\tbuild\n",
            "1\t \t-\tbuild\n",
            "",
            "1\tOne\t-\tbuild\n\n",
            "1\tBad\u{1b}title\t-\tbuild\n",
        ] {
            fs::write(plugin.path().join(STEPS_FILE), rows).unwrap();
            assert!(
                invoke(plugin.path(), project.path(), &["get"]).is_err(),
                "{rows:?}"
            );
        }
        fs::write(
            plugin.path().join(STEPS_FILE),
            "1\tTítulo\tworkspace/one.rb\tbuild\r\n",
        )
        .unwrap();
        assert_eq!(
            invoke(plugin.path(), project.path(), &["title"]).unwrap(),
            "Título\n".as_bytes()
        );
    }

    #[test]
    fn context_flags_override_environment_and_cwd_is_last_resort() {
        let explicit = args(
            Path::new("explicit-root"),
            Path::new("explicit-project"),
            &["get"],
        );
        let parsed = parse_args_in(
            &explicit,
            Some("env-root".into()),
            Some("env-project".into()),
            || panic!("cwd must not be inspected when project is explicit"),
        )
        .unwrap();
        assert_eq!(parsed.plugin_root, Path::new("explicit-root"));
        assert_eq!(parsed.project_dir, Path::new("explicit-project"));
        let command = vec![OsString::from("get")];
        let parsed = parse_args_in(
            &command,
            Some("env-root".into()),
            Some("env-project".into()),
            || panic!("cwd must not be inspected when environment supplies project"),
        )
        .unwrap();
        assert_eq!(parsed.plugin_root, Path::new("env-root"));
        assert_eq!(parsed.project_dir, Path::new("env-project"));
        let parsed =
            parse_args_in(&command, Some("env-root".into()), None, || Ok("cwd".into())).unwrap();
        assert_eq!(parsed.project_dir, Path::new("cwd"));
        assert_eq!(
            parse_args_in(&command, None, None, || Ok("cwd".into()))
                .unwrap_err()
                .code,
            2
        );
    }

    #[test]
    fn usage_errors_do_not_mutate_existing_state() {
        let (plugin, project) = setup(Modality::Interview, "", "1\tScope\tinterview\n");
        invoke(plugin.path(), project.path(), &["get"]).unwrap();
        let path = project.path().join(".test/progress.json");
        let raw = fs::read(&path).unwrap();
        for tail in [
            &["unknown"][..],
            &["get", "1"],
            &["spine"],
            &["kind"],
            &["title", "bad"],
            &["mode", "a", "b"],
        ] {
            assert_eq!(
                invoke(plugin.path(), project.path(), tail)
                    .unwrap_err()
                    .code,
                2
            );
            assert_eq!(fs::read(&path).unwrap(), raw);
        }
    }

    #[test]
    fn atomic_updates_are_valid_for_readers_without_lock_and_keep_lock_inode() {
        let (plugin, project) = setup(Modality::Interview, "", "1\tScope\tinterview\n");
        invoke(plugin.path(), project.path(), &["get"]).unwrap();
        let plugin = Arc::new(plugin);
        let project = Arc::new(project);
        let lock_path = project.path().join(".test/progress.lock");
        #[cfg(unix)]
        let inode = {
            use std::os::unix::fs::MetadataExt;
            fs::metadata(&lock_path).unwrap().ino()
        };
        let reader_project = Arc::clone(&project);
        let barrier = Arc::new(Barrier::new(2));
        let reader_barrier = Arc::clone(&barrier);
        let reader = thread::spawn(move || {
            reader_barrier.wait();
            for _ in 0..500 {
                let state = progress(reader_project.path());
                assert_eq!(state["step"], 1);
                assert!(state["mode"].is_string());
                thread::yield_now();
            }
        });
        barrier.wait();
        for number in 0..30 {
            invoke(
                plugin.path(),
                project.path(),
                &["set-mode", &format!("mode-{number}")],
            )
            .unwrap();
        }
        reader.join().unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            assert_eq!(fs::metadata(&lock_path).unwrap().ino(), inode);
        }
        assert_eq!(
            fs::read_dir(project.path().join(".test")).unwrap().count(),
            2
        );
    }

    #[cfg(unix)]
    #[test]
    fn rejects_symlink_escape_and_dangling_state_links_without_overwrite() {
        use std::os::unix::fs::symlink;
        let (plugin, project) = setup(Modality::Code, "", "1\tOne\tworkspace/one.rb\tbuild\n");
        let outside = tempfile::tempdir().unwrap();
        symlink(outside.path(), project.path().join("workspace")).unwrap();
        assert!(invoke(plugin.path(), project.path(), &["get"]).is_err());
        assert_eq!(fs::read_dir(outside.path()).unwrap().count(), 0);
        fs::remove_file(project.path().join("workspace")).unwrap();
        symlink(outside.path(), project.path().join(".test")).unwrap();
        assert!(invoke(plugin.path(), project.path(), &["get"]).is_err());
        fs::remove_file(project.path().join(".test")).unwrap();
        fs::create_dir(project.path().join(".test")).unwrap();
        let progress_path = project.path().join(".test/progress.json");
        symlink(outside.path().join("missing"), &progress_path).unwrap();
        assert!(invoke(plugin.path(), project.path(), &["status"]).is_err());
        assert!(
            fs::symlink_metadata(&progress_path)
                .unwrap()
                .file_type()
                .is_symlink()
        );
        assert_eq!(fs::read_dir(outside.path()).unwrap().count(), 0);
    }

    #[test]
    fn rejects_non_contiguous_steps_and_escaping_paths() {
        let (plugin, project) = setup(
            Modality::Code,
            "",
            "1\tOne\tworkspace/one.rb\tbuild\n3\tThree\tworkspace/three.rb\tbuild\n",
        );
        assert!(
            invoke(plugin.path(), project.path(), &["get"])
                .unwrap_err()
                .message
                .contains("contiguous")
        );

        fs::write(
            plugin.path().join(STEPS_FILE),
            "1\tOne\t../outside.rb\tbuild\n",
        )
        .unwrap();
        assert!(
            invoke(plugin.path(), project.path(), &["get"])
                .unwrap_err()
                .message
                .contains("must not escape")
        );
    }
}
