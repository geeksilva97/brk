use std::env;
use std::ffi::OsString;
use std::path::{Component, Path, PathBuf};

const MARKETPLACE_FILE: &str = ".claude-plugin/marketplace.json";

#[derive(Clone, Debug)]
pub struct Paths {
    pub config_dir: PathBuf,
    pub registries_file: PathBuf,
    pub cache_dir: PathBuf,
}

impl Paths {
    pub fn from_env() -> Result<Self, String> {
        let home = || {
            env::var_os("HOME")
                .map(PathBuf::from)
                .ok_or_else(|| "brk: HOME is not set and an XDG home is missing".to_string())
        };
        let config_home = match env::var_os("XDG_CONFIG_HOME") {
            Some(path) => PathBuf::from(path),
            None => home()?.join(".config"),
        };
        let cache_home = match env::var_os("XDG_CACHE_HOME") {
            Some(path) => PathBuf::from(path),
            None => home()?.join(".cache"),
        };
        let config_dir = config_home.join("brk");
        Ok(Self {
            registries_file: config_dir.join("registries"),
            config_dir,
            cache_dir: cache_home.join("brk"),
        })
    }
}

pub fn bundled_registry_root() -> Result<PathBuf, String> {
    if let Some(explicit) = env::var_os("BRK_HOME") {
        let root = PathBuf::from(explicit);
        return validate_bundled_root(&root).map_err(|error| {
            format!(
                "brk: BRK_HOME '{}' is not a registry: {error}",
                root.display()
            )
        });
    }

    if let Ok(executable) = env::current_exe() {
        let executable = executable.canonicalize().unwrap_or(executable);
        if let Some(parent) = executable.parent()
            && let Some(root) = find_registry_ancestor(parent)
        {
            return validate_bundled_root(&root)
                .map_err(|error| format!("brk: invalid bundled registry: {error}"));
        }
    }

    Err("brk: could not locate bundled content beside the executable; set BRK_HOME to a checkout containing .claude-plugin/marketplace.json".to_string())
}

fn find_registry_ancestor(start: &Path) -> Option<PathBuf> {
    start
        .ancestors()
        .find(|candidate| candidate.join(MARKETPLACE_FILE).is_file())
        .map(|candidate| {
            candidate
                .canonicalize()
                .unwrap_or_else(|_| candidate.to_path_buf())
        })
}

fn validate_bundled_root(root: &Path) -> Result<PathBuf, String> {
    if !root.join(MARKETPLACE_FILE).is_file() {
        return Err(format!("missing {MARKETPLACE_FILE}"));
    }
    crate::marketplace::read_marketplace(root)?;
    root.canonicalize()
        .map_err(|error| format!("cannot resolve '{}': {error}", root.display()))
}

pub fn validate_registry_name(name: &str) -> Result<(), String> {
    if name.is_empty()
        || name == "."
        || name.contains("..")
        || name.contains('/')
        || name.contains('\\')
        || !name.chars().all(|character| {
            character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.')
        })
    {
        return Err(format!("invalid registry name '{name}'"));
    }
    Ok(())
}

pub fn confined_relative_path(root: &Path, source: &str) -> Result<PathBuf, String> {
    let relative = Path::new(source);
    if relative.as_os_str().is_empty() || relative.is_absolute() {
        return Err("plugin source must be a non-empty relative path".to_string());
    }

    for component in relative.components() {
        match component {
            Component::CurDir | Component::Normal(_) => {}
            Component::ParentDir => {
                return Err(format!("plugin source '{source}' contains '..'"));
            }
            Component::RootDir | Component::Prefix(_) => {
                return Err(format!("plugin source '{source}' is not relative"));
            }
        }
    }

    let candidate = root.join(relative);
    if candidate.exists() {
        let canonical_root = root
            .canonicalize()
            .map_err(|error| format!("cannot resolve registry '{}': {error}", root.display()))?;
        let canonical_candidate = candidate.canonicalize().map_err(|error| {
            format!(
                "cannot resolve plugin source '{}': {error}",
                candidate.display()
            )
        })?;
        if !canonical_candidate.starts_with(&canonical_root) {
            return Err(format!("plugin source '{source}' escapes its registry"));
        }
        return Ok(canonical_candidate);
    }

    // The lexical check above protects missing paths. For an existing parent,
    // also reject a symlink that redirects the not-yet-created leaf outside.
    let mut existing = candidate.as_path();
    while !existing.exists() {
        existing = existing
            .parent()
            .ok_or_else(|| format!("invalid plugin source '{source}'"))?;
    }
    let canonical_root = root
        .canonicalize()
        .map_err(|error| format!("cannot resolve registry '{}': {error}", root.display()))?;
    let canonical_parent = existing
        .canonicalize()
        .map_err(|error| format!("cannot resolve '{}': {error}", existing.display()))?;
    if !canonical_parent.starts_with(&canonical_root) {
        return Err(format!("plugin source '{source}' escapes its registry"));
    }
    Ok(candidate)
}

pub fn os_to_text(value: &OsString, what: &str) -> Result<String, String> {
    value
        .to_str()
        .map(str::to_owned)
        .ok_or_else(|| format!("brk: {what} must be valid UTF-8"))
}

#[cfg(test)]
mod tests {
    use super::{confined_relative_path, validate_registry_name};
    use std::fs;

    #[test]
    fn cache_names_reject_traversal_and_separators() {
        for invalid in ["", ".", "..", "a..b", "a/b", "a\\b"] {
            assert!(
                validate_registry_name(invalid).is_err(),
                "accepted {invalid:?}"
            );
        }
        for valid in ["acme", "acme-dojos", "acme_2", "acme.example"] {
            assert!(validate_registry_name(valid).is_ok(), "rejected {valid:?}");
        }
    }

    #[test]
    fn relative_sources_stay_inside_the_registry() {
        let temp = tempfile::tempdir().unwrap();
        fs::create_dir(temp.path().join("dojo")).unwrap();
        assert!(confined_relative_path(temp.path(), "./dojo").is_ok());
        assert!(confined_relative_path(temp.path(), "../elsewhere").is_err());
        assert!(confined_relative_path(temp.path(), "dojo/../elsewhere").is_err());
        assert!(confined_relative_path(temp.path(), "/elsewhere").is_err());
    }

    #[cfg(unix)]
    #[test]
    fn relative_sources_reject_escaping_symlinks() {
        use std::os::unix::fs::symlink;
        let registry = tempfile::tempdir().unwrap();
        let outside = tempfile::tempdir().unwrap();
        symlink(outside.path(), registry.path().join("escape")).unwrap();
        assert!(confined_relative_path(registry.path(), "escape/dojo").is_err());
    }
}
