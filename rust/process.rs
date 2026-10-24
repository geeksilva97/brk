use regex::Regex;
use std::collections::HashSet;
use std::env;
use std::ffi::{OsStr, OsString};
use std::path::Path;
use std::process::{Command, ExitStatus, Stdio};

pub struct CommandOutput {
    pub code: i32,
    pub stdout: String,
    pub stderr: String,
}

pub fn launch_dojo(plugin_dir: &Path, cwd: &Path, extra: &[OsString], jail: bool) -> i32 {
    let executable = claude_bin();
    let mut command = Command::new(&executable);
    command.arg("--plugin-dir").arg(plugin_dir).args(extra);
    if jail {
        command.args(["--disallowed-tools", "WebSearch", "WebFetch"]);
        command.env("CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION", "false");
    }
    // Older/external plugins and forge output may not have native state config.
    // Never leak a parent session's runtime into an unsupported plugin.
    command.env_remove("BRK_RUNTIME_BIN");
    if plugin_dir.join("brk.json").is_file()
        && let Ok(runtime) = env::current_exe()
    {
        command.env("BRK_RUNTIME_BIN", runtime);
    }
    command
        .current_dir(cwd)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    match command.status() {
        Ok(status) => status_code(status),
        Err(error) => {
            eprintln!(
                "brk: could not launch '{}': {error}",
                executable.to_string_lossy()
            );
            127
        }
    }
}

pub fn claude_plugin(args: &[OsString], inherit: bool) -> Result<CommandOutput, String> {
    let executable = claude_bin();
    let mut command = Command::new(&executable);
    command.arg("plugin").args(args);
    if inherit {
        command
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit());
        let status = command.status().map_err(|error| {
            format!(
                "could not launch '{}': {error}",
                executable.to_string_lossy()
            )
        })?;
        Ok(CommandOutput {
            code: status_code(status),
            stdout: String::new(),
            stderr: String::new(),
        })
    } else {
        let output = command.output().map_err(|error| {
            format!(
                "could not launch '{}': {error}",
                executable.to_string_lossy()
            )
        })?;
        Ok(CommandOutput {
            code: status_code(output.status),
            stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
        })
    }
}

pub fn installed_ids() -> HashSet<String> {
    let Ok(output) = claude_plugin(&[OsString::from("list")], false) else {
        return HashSet::new();
    };
    if output.code != 0 {
        return HashSet::new();
    }
    let pattern = Regex::new(r"(?i)([a-z0-9][\w-]*)@([a-z0-9][\w-]*)").unwrap();
    pattern
        .captures_iter(&output.stdout)
        .map(|captures| format!("{}@{}", &captures[1], &captures[2]))
        .collect()
}

pub fn git(args: &[OsString]) -> Result<CommandOutput, String> {
    let output = Command::new("git")
        .args(args)
        .output()
        .map_err(|error| format!("could not launch 'git': {error}"))?;
    Ok(CommandOutput {
        code: status_code(output.status),
        stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    })
}

fn claude_bin() -> OsString {
    env::var_os("BRK_CLAUDE_BIN").unwrap_or_else(|| OsString::from("claude"))
}

pub fn status_code(status: ExitStatus) -> i32 {
    if let Some(code) = status.code() {
        return code;
    }
    #[cfg(unix)]
    {
        use std::os::unix::process::ExitStatusExt;
        if let Some(signal) = status.signal() {
            return 128 + signal;
        }
    }
    1
}

pub fn os(value: impl AsRef<OsStr>) -> OsString {
    value.as_ref().to_os_string()
}
