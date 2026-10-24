use crate::marketplace::describe;
use crate::paths::{Paths, os_to_text, validate_registry_name};
use crate::process::{claude_plugin, installed_ids, launch_dojo, os};
use crate::registry::{RegistryKind, list_registries, refresh, registry_contents, resolve_dojo};
use serde_json::Value;
use std::env;
use std::ffi::{OsStr, OsString};
use std::fs;
use std::path::{Path, PathBuf};

const WATCH_LOOP_PROMPT: &str = include_str!("watch.txt");

const HELP: &str = "brk — install or start tutored coding-dojo plugins for Claude Code

USAGE
  brk <command> [args]

COMMANDS
  run [--watch] <name> [dir] [args]  Start a dojo right away (ephemeral, nothing installed).
                                    Runs in <dir> (created if given), offline jail on.
                                    --watch (-w): auto-review your code on each save.
  install <name>                   Install a dojo persistently (native Claude Code plugin).
  uninstall <name>                 Remove an installed dojo.
  list                             List every dojo across all registries.
  update                           Refresh registry content (re-run install.sh to rebuild CLI).
  state [options] <command>        Read or update per-project dojo progress.
  hook <event> [options]           Run a native session-start or title hook.
  new [topic]                      Author a new dojo with the dojo-forge generator.
  registry add <git-url> [name]    Add another registry (an org's dojos repo).
  registry list                    Show configured registries.
  registry remove <url|name>       Remove a registry.
  help                             Show this help.

EXAMPLES
  brk list
  brk run demonkey ./my-workshop
  brk run --watch demonkey ./my-workshop
  brk install c10k-dojo
  brk registry add git@github.com:acme/dojos.git acme
";

pub fn main(args: &[OsString]) -> i32 {
    let (command, rest) = match args.split_first() {
        Some(parts) => parts,
        None => return cmd_help(),
    };
    match command.to_str() {
        Some("run") => cmd_run(rest),
        Some("install") => cmd_install(rest),
        Some("uninstall") => cmd_uninstall(rest),
        Some("list" | "ls") => cmd_list(),
        Some("update") => cmd_update(),
        Some("registry") => cmd_registry(rest),
        Some("new") => cmd_new(rest),
        Some("help" | "--help" | "-h") => cmd_help(),
        Some(command) => {
            eprintln!("brk: unknown command '{command}'. Run 'brk help'.");
            2
        }
        None => {
            eprintln!("brk: command must be valid UTF-8. Run 'brk help'.");
            2
        }
    }
}

fn cmd_help() -> i32 {
    print!("{HELP}");
    0
}

#[derive(Debug, PartialEq, Eq)]
struct RunArgs {
    watch: bool,
    name: String,
    project_dir: Option<PathBuf>,
    forwarded: Vec<OsString>,
}

fn parse_run_args(args: &[OsString]) -> Result<RunArgs, String> {
    let delimiter = args.iter().position(|arg| arg == OsStr::new("--"));
    let before = &args[..delimiter.unwrap_or(args.len())];
    let after = delimiter.map_or(&[][..], |position| &args[position + 1..]);

    let watch = before
        .iter()
        .any(|arg| arg == OsStr::new("--watch") || arg == OsStr::new("-w"));
    let mut legacy: Vec<OsString> = before
        .iter()
        .filter(|arg| *arg != OsStr::new("--watch") && *arg != OsStr::new("-w"))
        .cloned()
        .collect();
    if legacy.is_empty() {
        return Err("usage: brk run [--watch] <name> [project-dir] [claude args...]".to_string());
    }
    let name = os_to_text(&legacy.remove(0), "dojo name")?;
    let project_dir = legacy
        .first()
        .filter(|arg| !arg.as_os_str().as_encoded_bytes().starts_with(b"-"))
        .map(|arg| PathBuf::from(arg.as_os_str()));
    if project_dir.is_some() {
        legacy.remove(0);
    }
    legacy.extend_from_slice(after);
    Ok(RunArgs {
        watch,
        name,
        project_dir,
        forwarded: legacy,
    })
}

fn cmd_run(args: &[OsString]) -> i32 {
    let parsed = match parse_run_args(args) {
        Ok(parsed) => parsed,
        Err(error) => {
            eprintln!("{error}");
            return 2;
        }
    };
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let found = match resolve_dojo(&paths, &parsed.name) {
        Ok(Some(found)) => found,
        Ok(None) => {
            eprintln!(
                "brk: unknown dojo '{}'. Run 'brk list' to see what's available.",
                parsed.name
            );
            return 1;
        }
        Err(error) => return print_error(error),
    };
    let Some(plugin_dir) = found.dir else {
        eprintln!(
            "brk: '{}' resolves to a source this CLI can't run ephemerally; try 'brk install {}'.",
            parsed.name, parsed.name
        );
        return 1;
    };
    if !plugin_dir.exists() {
        eprintln!(
            "brk: '{}' resolves to a source this CLI can't run ephemerally; try 'brk install {}'.",
            parsed.name, parsed.name
        );
        return 1;
    }
    if parsed.watch && is_interview_dojo(&plugin_dir) {
        eprintln!(
            "brk: --watch is not supported for interview dojos such as '{}'; run it without --watch.",
            parsed.name
        );
        return 1;
    }

    let cwd = match parsed.project_dir {
        Some(directory) => {
            if let Err(error) = fs::create_dir_all(&directory) {
                eprintln!(
                    "brk: cannot create project directory '{}': {error}",
                    directory.display()
                );
                return 1;
            }
            match directory.canonicalize() {
                Ok(directory) => directory,
                Err(error) => {
                    eprintln!(
                        "brk: cannot resolve project directory '{}': {error}",
                        directory.display()
                    );
                    return 1;
                }
            }
        }
        None => match env::current_dir() {
            Ok(directory) => directory,
            Err(error) => {
                eprintln!("brk: cannot determine current directory: {error}");
                return 1;
            }
        },
    };
    let mut forwarded = parsed.forwarded;
    if parsed.watch {
        forwarded.push(OsString::from(WATCH_LOOP_PROMPT));
    }
    launch_dojo(&plugin_dir, &cwd, &forwarded, true)
}

fn is_interview_dojo(plugin_dir: &Path) -> bool {
    let Ok(contents) = fs::read_to_string(plugin_dir.join("brk.json")) else {
        return false;
    };
    let Ok(config) = serde_json::from_str::<Value>(&contents) else {
        return false;
    };
    config.get("modality").and_then(Value::as_str) == Some("interview")
}

fn cmd_install(args: &[OsString]) -> i32 {
    let Some(name_arg) = args.first() else {
        eprintln!("usage: brk install <name>");
        return 2;
    };
    let name = match os_to_text(name_arg, "dojo name") {
        Ok(name) => name,
        Err(error) => return print_error(error),
    };
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let found = match resolve_dojo(&paths, &name) {
        Ok(Some(found)) => found,
        Ok(None) => {
            eprintln!("brk: unknown dojo '{name}'. Run 'brk list' to see what's available.");
            return 1;
        }
        Err(error) => return print_error(error),
    };
    let source = match found.registry.kind {
        RegistryKind::Git => OsString::from(&found.registry.location),
        RegistryKind::Local => found.registry.root.as_os_str().to_owned(),
    };
    let added = match claude_plugin(&[os("marketplace"), os("add"), source], false) {
        Ok(result) if result.code == 0 => result,
        Ok(result) => {
            report_subprocess_failure("marketplace add", result.code, &result.stderr);
            return nonzero(result.code);
        }
        Err(error) => return print_error(format!("brk: {error}")),
    };
    drop(added);

    let id = format!("{}@{}", found.entry.name, found.marketplace_name);
    match claude_plugin(&[os("install"), os(&id)], true) {
        Ok(result) => {
            if result.code == 0 {
                eprintln!(
                    "brk: installed {id}. Start it in any project with /{}:start",
                    found.entry.name
                );
            }
            result.code
        }
        Err(error) => print_error(format!("brk: {error}")),
    }
}

fn cmd_uninstall(args: &[OsString]) -> i32 {
    let Some(name_arg) = args.first() else {
        eprintln!("usage: brk uninstall <name>");
        return 2;
    };
    let name = match os_to_text(name_arg, "dojo name") {
        Ok(name) => name,
        Err(error) => return print_error(error),
    };
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let found = match resolve_dojo(&paths, &name) {
        Ok(Some(found)) => found,
        Ok(None) => {
            eprintln!("brk: unknown dojo '{name}'.");
            return 1;
        }
        Err(error) => return print_error(error),
    };
    let id = format!("{}@{}", found.entry.name, found.marketplace_name);
    match claude_plugin(&[os("uninstall"), os(id)], true) {
        Ok(result) => result.code,
        Err(error) => print_error(format!("brk: {error}")),
    }
}

fn cmd_list() -> i32 {
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let registries = match list_registries(&paths) {
        Ok(registries) => registries,
        Err(error) => return print_error(error),
    };
    let installed = installed_ids();
    let mut any = false;
    for registry in registries {
        let contents = registry_contents(&registry);
        let Some(marketplace) = contents.marketplace else {
            println!(
                "\n{}  (unavailable: {})",
                registry.name,
                contents.error.as_deref().unwrap_or("could not read")
            );
            continue;
        };
        if registry.kind == RegistryKind::Git {
            println!("\n{}  ({})", registry.name, registry.location);
        } else {
            println!("\n{}", registry.name);
        }
        for entry in &marketplace.plugins {
            any = true;
            let marker = if installed.contains(&format!("{}@{}", entry.name, marketplace.name)) {
                " [installed]"
            } else {
                ""
            };
            let description = trim_description(&describe(&registry.root, entry), 92);
            println!("  {:<16}{:<13}{}", entry.name, marker, description);
        }
    }
    if !any {
        println!("No dojos found.");
    } else {
        println!("\nStart one with 'brk run <name>' or install with 'brk install <name>'.");
    }
    0
}

fn trim_description(description: &str, limit: usize) -> String {
    let normalized = description.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.chars().count() <= limit {
        return normalized;
    }
    let prefix: String = normalized.chars().take(limit - 1).collect();
    format!("{prefix}…")
}

fn cmd_update() -> i32 {
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let registries = match list_registries(&paths) {
        Ok(registries) => registries,
        Err(error) => return print_error(error),
    };
    let mut failed = false;
    for registry in registries {
        match refresh(&registry) {
            Ok(true) => println!("{}: not a git checkout (skipped)", registry.name),
            Ok(false) => println!("{}: updated", registry.name),
            Err(error) => {
                failed = true;
                let operation = if registry.kind == RegistryKind::Local {
                    "pull"
                } else {
                    "fetch"
                };
                println!("{}: {operation} failed — {error}", registry.name);
            }
        }
    }
    match claude_plugin(&[os("marketplace"), os("update")], false) {
        Ok(result) if result.code == 0 => {}
        Ok(result) => {
            failed = true;
            report_subprocess_failure("marketplace update", result.code, &result.stderr);
        }
        Err(error) => {
            failed = true;
            eprintln!("brk: {error}");
        }
    }
    println!(
        "brk: registry content refreshed; re-run install.sh to rebuild the native CLI after source changes."
    );
    i32::from(failed)
}

fn cmd_registry(args: &[OsString]) -> i32 {
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    match args.first().and_then(|arg| arg.to_str()) {
        Some("add") => registry_add(&paths, &args[1..]),
        Some("remove" | "rm") => registry_remove(&paths, &args[1..]),
        Some("list") | None => registry_list(&paths),
        Some(subcommand) => {
            eprintln!(
                "brk: unknown 'registry' subcommand '{subcommand}'. Use add | list | remove."
            );
            2
        }
    }
}

fn registry_add(paths: &Paths, args: &[OsString]) -> i32 {
    let Some(location_arg) = args.first() else {
        eprintln!("usage: brk registry add <git-url> [name]");
        return 2;
    };
    let location = match os_to_text(location_arg, "registry URL") {
        Ok(location)
            if !location.is_empty()
                && !location.starts_with('-')
                && !location.chars().any(char::is_whitespace) =>
        {
            location
        }
        Ok(_) => {
            eprintln!(
                "brk: registry URL must be non-empty, must not start with '-', and cannot contain whitespace."
            );
            return 2;
        }
        Err(error) => return print_error(error),
    };
    if args.len() > 2 {
        eprintln!("usage: brk registry add <git-url> [name]");
        return 2;
    }
    let explicit_name = match args.get(1) {
        Some(value) => match os_to_text(value, "registry name") {
            Ok(name) => Some(name),
            Err(error) => return print_error(error),
        },
        None => None,
    };
    let name = explicit_name
        .clone()
        .unwrap_or_else(|| crate::registry::derive_name(&location));
    if let Err(error) = validate_registry_name(&name) {
        eprintln!("brk: {error}.");
        return 2;
    }
    let mut lines = match read_registry_lines(paths) {
        Ok(lines) => lines,
        Err(error) => return print_error(error),
    };
    if lines
        .iter()
        .filter(|line| !line.starts_with('#'))
        .any(|line| line.split_whitespace().next() == Some(location.as_str()))
    {
        eprintln!("brk: registry '{location}' is already added.");
        return 0;
    }
    let known = match list_registries(paths) {
        Ok(registries) => registries,
        Err(error) => return print_error(error),
    };
    if known
        .iter()
        .any(|registry| registry.name.eq_ignore_ascii_case(&name))
    {
        eprintln!("brk: registry name '{name}' is already in use; choose a different name.");
        return 2;
    }
    lines.push(match explicit_name {
        Some(name) => format!("{location} {name}"),
        None => location.clone(),
    });
    if let Err(error) = write_registry_lines(paths, &lines) {
        return print_error(error);
    }
    eprintln!(
        "brk: added registry {location}{}.",
        if args.get(1).is_some() {
            format!(" ({name})")
        } else {
            String::new()
        }
    );
    0
}

fn registry_remove(paths: &Paths, args: &[OsString]) -> i32 {
    let Some(target_arg) = args.first() else {
        eprintln!("usage: brk registry remove <git-url|name>");
        return 2;
    };
    let target = match os_to_text(target_arg, "registry target") {
        Ok(target) => target,
        Err(error) => return print_error(error),
    };
    let before = match read_registry_lines(paths) {
        Ok(lines) => lines,
        Err(error) => return print_error(error),
    };
    let after: Vec<String> = before
        .iter()
        .filter(|line| {
            let mut fields = line.split_whitespace();
            let location = fields.next();
            let name = fields
                .next()
                .map(str::to_owned)
                .or_else(|| location.map(crate::registry::derive_name));
            location != Some(target.as_str()) && name.as_deref() != Some(target.as_str())
        })
        .cloned()
        .collect();
    if after.len() == before.len() {
        eprintln!("brk: no registry matching '{target}'.");
        return 1;
    }
    if let Err(error) = write_registry_lines(paths, &after) {
        return print_error(error);
    }
    eprintln!("brk: removed '{target}'.");
    0
}

fn registry_list(paths: &Paths) -> i32 {
    let registries = match list_registries(paths) {
        Ok(registries) => registries,
        Err(error) => return print_error(error),
    };
    for registry in registries {
        let (marker, location) = match registry.kind {
            RegistryKind::Local => ("(bundled)", registry.root.to_string_lossy().into_owned()),
            RegistryKind::Git => ("", registry.location),
        };
        println!("{:<20} {} {}", registry.name, marker, location);
    }
    println!("\nconfig: {}", paths.registries_file.display());
    0
}

fn read_registry_lines(paths: &Paths) -> Result<Vec<String>, String> {
    if !paths.registries_file.exists() {
        return Ok(Vec::new());
    }
    fs::read_to_string(&paths.registries_file)
        .map(|contents| {
            contents
                .lines()
                .map(str::trim)
                .filter(|line| !line.is_empty())
                .map(str::to_owned)
                .collect()
        })
        .map_err(|error| {
            format!(
                "brk: cannot read '{}': {error}",
                paths.registries_file.display()
            )
        })
}

fn write_registry_lines(paths: &Paths, lines: &[String]) -> Result<(), String> {
    fs::create_dir_all(&paths.config_dir).map_err(|error| {
        format!(
            "brk: cannot create '{}': {error}",
            paths.config_dir.display()
        )
    })?;
    let mut contents = lines.join("\n");
    if !lines.is_empty() {
        contents.push('\n');
    }
    fs::write(&paths.registries_file, contents).map_err(|error| {
        format!(
            "brk: cannot write '{}': {error}",
            paths.registries_file.display()
        )
    })
}

fn cmd_new(args: &[OsString]) -> i32 {
    let paths = match runtime_paths() {
        Ok(paths) => paths,
        Err(code) => return code,
    };
    let found = match resolve_dojo(&paths, "dojo-forge") {
        Ok(Some(found)) => found,
        Ok(None) => {
            eprintln!("brk: the 'dojo-forge' generator isn't available in any registry.");
            return 1;
        }
        Err(error) => return print_error(error),
    };
    let Some(plugin_dir) = found.dir.filter(|directory| directory.exists()) else {
        eprintln!("brk: the 'dojo-forge' generator isn't available in any registry.");
        return 1;
    };
    let topic = args
        .iter()
        .map(|argument| argument.to_string_lossy())
        .collect::<Vec<_>>()
        .join(" ")
        .trim()
        .to_string();
    let extra = if topic.is_empty() {
        Vec::new()
    } else {
        vec![OsString::from(format!("/dojo-forge:new {topic}"))]
    };
    let cwd = match env::current_dir() {
        Ok(directory) => directory,
        Err(error) => {
            eprintln!("brk: cannot determine current directory: {error}");
            return 1;
        }
    };
    launch_dojo(&plugin_dir, &cwd, &extra, false)
}

fn runtime_paths() -> Result<Paths, i32> {
    Paths::from_env().map_err(print_error)
}

fn print_error(error: String) -> i32 {
    eprintln!("{error}");
    1
}

fn nonzero(code: i32) -> i32 {
    if code == 0 { 1 } else { code }
}

fn report_subprocess_failure(operation: &str, code: i32, stderr: &str) {
    let detail = stderr
        .lines()
        .next()
        .map(str::trim)
        .filter(|line| !line.is_empty());
    if let Some(detail) = detail {
        eprintln!("brk: {operation} failed (exit {code}): {detail}");
    } else {
        eprintln!("brk: {operation} failed (exit {code}).");
    }
}

#[cfg(test)]
mod tests {
    use super::parse_run_args;
    use std::ffi::OsString;
    use std::path::PathBuf;

    fn args(values: &[&str]) -> Vec<OsString> {
        values.iter().map(OsString::from).collect()
    }

    #[test]
    fn run_parser_preserves_legacy_project_and_flags() {
        let parsed =
            parse_run_args(&args(&["--watch", "demonkey", "./work", "--model", "qwen"])).unwrap();
        assert!(parsed.watch);
        assert_eq!(parsed.name, "demonkey");
        assert_eq!(parsed.project_dir, Some(PathBuf::from("./work")));
        assert_eq!(parsed.forwarded, args(&["--model", "qwen"]));
    }

    #[test]
    fn delimiter_forwards_watch_instead_of_consuming_it() {
        let parsed = parse_run_args(&args(&["demonkey", "--", "--watch", "-w"])).unwrap();
        assert!(!parsed.watch);
        assert_eq!(parsed.project_dir, None);
        assert_eq!(parsed.forwarded, args(&["--watch", "-w"]));
    }

    #[test]
    fn watch_is_only_recognized_before_delimiter() {
        let parsed = parse_run_args(&args(&["-w", "demonkey", "--", "hello"])).unwrap();
        assert!(parsed.watch);
        assert_eq!(parsed.forwarded, args(&["hello"]));
    }
}
