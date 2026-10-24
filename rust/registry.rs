use crate::marketplace::{Marketplace, PluginEntry, plugin_dir, read_marketplace};
use crate::paths::{Paths, bundled_registry_root, validate_registry_name};
use crate::process::{git, os};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{ErrorKind, Write};
use std::path::{Path, PathBuf};
use tempfile::NamedTempFile;

const CACHE_SOURCE_FILE: &str = "brk-source.json";

#[derive(Deserialize, Serialize)]
struct CacheSource {
    schema_version: u32,
    location: String,
    origin: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RegistryKind {
    Local,
    Git,
}

#[derive(Clone, Debug)]
pub struct Registry {
    pub name: String,
    pub kind: RegistryKind,
    pub location: String,
    pub root: PathBuf,
}

#[derive(Clone, Debug)]
pub struct ResolvedDojo {
    pub registry: Registry,
    pub entry: PluginEntry,
    pub dir: Option<PathBuf>,
    pub marketplace_name: String,
}

pub struct RegistryContents {
    pub marketplace: Option<Marketplace>,
    pub error: Option<String>,
}

pub fn derive_name(location: &str) -> String {
    let trimmed = location.trim_end_matches(['/', '\\']);
    let tail = trimmed
        .rsplit(['/', '\\', ':'])
        .find(|part| !part.is_empty())
        .unwrap_or("registry");
    let name = tail.strip_suffix(".git").unwrap_or(tail);
    if name.is_empty() {
        "registry".to_string()
    } else {
        name.to_string()
    }
}

pub fn list_registries(paths: &Paths) -> Result<Vec<Registry>, String> {
    let root = bundled_registry_root()?;
    let bundled_name = read_marketplace(&root)
        .map(|marketplace| marketplace.name)
        .unwrap_or_else(|_| "brk".to_string());
    let mut registries = vec![Registry {
        name: bundled_name,
        kind: RegistryKind::Local,
        location: root.to_string_lossy().into_owned(),
        root,
    }];

    if !paths.registries_file.exists() {
        return Ok(registries);
    }
    let contents = fs::read_to_string(&paths.registries_file).map_err(|error| {
        format!(
            "brk: cannot read registry config '{}': {error}",
            paths.registries_file.display()
        )
    })?;
    for (index, line) in contents.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let mut fields = trimmed.split_whitespace();
        let Some(location) = fields.next() else {
            continue;
        };
        let name = fields
            .next()
            .map(str::to_owned)
            .unwrap_or_else(|| derive_name(location));
        if fields.next().is_some() {
            return Err(format!(
                "brk: invalid registry config at {}:{}: expected '<git-url> [name]'",
                paths.registries_file.display(),
                index + 1
            ));
        }
        validate_registry_name(&name).map_err(|error| {
            format!(
                "brk: invalid registry config at {}:{}: {error}",
                paths.registries_file.display(),
                index + 1
            )
        })?;
        if registries
            .iter()
            .any(|registry| registry.name.eq_ignore_ascii_case(&name))
        {
            return Err(format!(
                "brk: duplicate registry name '{name}' in configuration"
            ));
        }
        registries.push(Registry {
            root: paths.cache_dir.join(&name),
            name,
            kind: RegistryKind::Git,
            location: location.to_string(),
        });
    }
    Ok(registries)
}

/// Clone on first use, but never refresh an existing cache implicitly.
/// Marked caches need no git process; legacy caches validate their local origin once.
pub fn registry_contents(registry: &Registry) -> RegistryContents {
    if registry.kind == RegistryKind::Git
        && let Err(error) = clone_or_pull(&registry.location, &registry.root, false)
    {
        return RegistryContents {
            marketplace: None,
            error: Some(error),
        };
    }
    match read_marketplace(&registry.root) {
        Ok(marketplace) => RegistryContents {
            marketplace: Some(marketplace),
            error: None,
        },
        Err(error) => RegistryContents {
            marketplace: None,
            error: Some(error),
        },
    }
}

pub fn resolve_dojo(paths: &Paths, name: &str) -> Result<Option<ResolvedDojo>, String> {
    let registries = list_registries(paths)?;
    for registry in registries {
        let contents = registry_contents(&registry);
        let Some(marketplace) = contents.marketplace else {
            continue;
        };
        let Some(entry) = marketplace
            .plugins
            .iter()
            .find(|entry| entry.name == name)
            .cloned()
        else {
            continue;
        };
        let dir = plugin_dir(&registry.root, &entry)?;
        return Ok(Some(ResolvedDojo {
            registry,
            entry,
            dir,
            marketplace_name: marketplace.name,
        }));
    }
    Ok(None)
}

pub fn refresh(registry: &Registry) -> Result<bool, String> {
    if registry.kind == RegistryKind::Local {
        return pull_if_repo(&registry.root);
    }
    clone_or_pull(&registry.location, &registry.root, true).map(|_| false)
}

/// Returns true when a local non-git registry was skipped.
fn pull_if_repo(root: &Path) -> Result<bool, String> {
    // A checkout can use either a .git directory or a .git indirection file
    // (notably worktrees), so existence is the correct test here.
    if !root.join(".git").exists() {
        return Ok(true);
    }
    let output = git(&[
        os("-C"),
        root.as_os_str().to_owned(),
        os("pull"),
        os("--ff-only"),
        os("--quiet"),
    ])?;
    if output.code == 0 {
        Ok(false)
    } else {
        Err(first_line(&output.stderr))
    }
}

fn cache_error(root: &Path, reason: &str) -> String {
    format!(
        "cache '{}' {reason}; choose a new registry alias or manually move the cache directory out of the way (no data was removed)",
        root.display()
    )
}

// symlink_metadata also catches dangling links. In particular, never follow a
// cache/.git/metadata link into another checkout, or treat it as a missing cache.
fn cache_path_exists(path: &Path, directory: bool, root: &Path) -> Result<bool, String> {
    match fs::symlink_metadata(path) {
        Ok(metadata) if metadata.file_type().is_symlink() => Err(cache_error(
            root,
            &format!("contains a symlink at '{}'", path.display()),
        )),
        Ok(metadata) if (directory && metadata.is_dir()) || (!directory && metadata.is_file()) => {
            Ok(true)
        }
        Ok(_) => Err(cache_error(
            root,
            &format!("has an unexpected file type at '{}'", path.display()),
        )),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(false),
        Err(error) => Err(cache_error(
            root,
            &format!("cannot inspect '{}': {error}", path.display()),
        )),
    }
}

fn read_cache_source(root: &Path, location: &str) -> Result<Option<CacheSource>, String> {
    let file = root.join(".git").join(CACHE_SOURCE_FILE);
    if !cache_path_exists(&file, false, root)? {
        return Ok(None);
    }
    let contents = fs::read(&file)
        .map_err(|error| cache_error(root, &format!("cannot read source metadata: {error}")))?;
    let source: CacheSource = serde_json::from_slice(&contents)
        .map_err(|error| cache_error(root, &format!("has invalid source metadata: {error}")))?;
    if source.schema_version != 1 || source.origin.is_empty() {
        return Err(cache_error(root, "has unsupported source metadata"));
    }
    // Deliberately exact: equivalent spellings are not proof that this alias
    // still denotes the same source. Never rebind or reset an existing cache.
    if source.location != location {
        return Err(cache_error(
            root,
            "belongs to a different registry location",
        ));
    }
    Ok(Some(source))
}

fn write_cache_source(root: &Path, source: &CacheSource) -> Result<(), String> {
    // .git is not part of the remote's tracked tree. Keeping the sidecar here
    // also avoids collisions with registry aliases such as `.shared-source.json`.
    let git_dir = root.join(".git");
    let file = git_dir.join(CACHE_SOURCE_FILE);
    if cache_path_exists(&file, false, root)? {
        return Err(cache_error(
            root,
            "already has source metadata; refusing to overwrite it",
        ));
    }
    let write = || -> Result<(), Box<dyn std::error::Error>> {
        let mut temporary = NamedTempFile::new_in(&git_dir)?;
        serde_json::to_writer(&mut temporary, source)?;
        temporary.write_all(b"\n")?;
        temporary.as_file().sync_all()?;
        temporary.persist_noclobber(&file)?;
        Ok(())
    };
    write().map_err(|error| cache_error(root, &format!("cannot save source metadata: {error}")))
}

fn cache_origin(root: &Path) -> Result<String, String> {
    // Read only this checkout's config: no network, hooks, inherited repository
    // discovery or include files. Used once for legacy migration and on update,
    // never for list/run/install of a cache already carrying source metadata.
    let config = root.join(".git/config");
    if !cache_path_exists(&config, false, root)? {
        return Err(cache_error(root, "has no local git config"));
    }
    let output = git(&[
        os("config"),
        os("--file"),
        config.as_os_str().to_owned(),
        os("--no-includes"),
        os("--null"),
        os("--get-all"),
        os("remote.origin.url"),
    ])?;
    let urls: Vec<_> = output.stdout.split_terminator('\0').collect();
    if output.code != 0 || urls.len() != 1 || urls[0].is_empty() {
        return Err(cache_error(
            root,
            "cannot validate a single local remote.origin.url",
        ));
    }
    Ok(urls[0].to_string())
}

fn clone_or_pull(location: &str, root: &Path, refresh: bool) -> Result<(), String> {
    if let Some(parent) = root.parent() {
        cache_path_exists(parent, true, root)?;
    }
    if cache_path_exists(root, true, root)? {
        if !cache_path_exists(&root.join(".git"), true, root)? {
            return Err(cache_error(root, "exists but is not a git checkout"));
        }
        let source = match read_cache_source(root, location)? {
            Some(source) => source,
            None => {
                let origin = cache_origin(root)?;
                if origin != location {
                    return Err(cache_error(
                        root,
                        "has a remote.origin.url that differs from the registry location",
                    ));
                }
                let source = CacheSource {
                    schema_version: 1,
                    location: location.to_string(),
                    origin,
                };
                write_cache_source(root, &source)?;
                source
            }
        };
        if !refresh {
            return Ok(());
        }
        if cache_origin(root)? != source.origin {
            return Err(cache_error(root, "has a changed remote.origin.url"));
        }
        let output = git(&[
            os("-C"),
            root.as_os_str().to_owned(),
            os("pull"),
            os("--ff-only"),
            os("--quiet"),
            os("origin"),
        ])?;
        return if output.code == 0 {
            Ok(())
        } else {
            Err(first_line(&output.stderr))
        };
    }
    if let Some(parent) = root.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("cannot create '{}': {error}", parent.display()))?;
    }
    let output = git(&[
        os("clone"),
        os("--quiet"),
        os("--depth"),
        os("1"),
        os("--"),
        os(location),
        root.as_os_str().to_owned(),
    ])?;
    if output.code != 0 {
        return Err(first_line(&output.stderr));
    }
    if !cache_path_exists(root, true, root)? || !cache_path_exists(&root.join(".git"), true, root)?
    {
        return Err(cache_error(root, "clone did not produce a git checkout"));
    }
    // Git can make a relative local clone URL absolute. Remember its actual
    // origin separately without weakening the exact configured-location binding.
    let origin = cache_origin(root)?;
    write_cache_source(
        root,
        &CacheSource {
            schema_version: 1,
            location: location.to_string(),
            origin,
        },
    )
}

fn first_line(message: &str) -> String {
    message
        .lines()
        .next()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .unwrap_or("unknown error")
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::{
        CACHE_SOURCE_FILE, CacheSource, derive_name, read_cache_source, write_cache_source,
    };
    use std::fs;

    #[test]
    fn source_metadata_binds_exact_location_and_never_overwrites() {
        let root = tempfile::tempdir().unwrap();
        let git_dir = root.path().join(".git");
        fs::create_dir(&git_dir).unwrap();
        let source = CacheSource {
            schema_version: 1,
            location: "file:///registry.git".to_string(),
            origin: "file:///registry.git".to_string(),
        };
        write_cache_source(root.path(), &source).unwrap();
        let file = git_dir.join(CACHE_SOURCE_FILE);
        let before = fs::read(&file).unwrap();
        assert_eq!(
            read_cache_source(root.path(), &source.location)
                .unwrap()
                .unwrap()
                .location,
            source.location
        );
        assert!(read_cache_source(root.path(), "file:///registry.git/").is_err());
        assert!(write_cache_source(root.path(), &source).is_err());
        assert_eq!(fs::read(&file).unwrap(), before);
        assert_eq!(fs::read_dir(&git_dir).unwrap().count(), 1);
    }

    #[test]
    fn derives_consistent_registry_names() {
        assert_eq!(derive_name("https://example.test/acme/dojos.git"), "dojos");
        assert_eq!(derive_name("git@example.test:acme/dojos.git"), "dojos");
        assert_eq!(derive_name("/tmp/dojos/"), "dojos");
    }
}
