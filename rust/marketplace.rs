use crate::paths::confined_relative_path;
use serde::Deserialize;
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Deserialize)]
pub struct Marketplace {
    pub name: String,
    #[serde(default)]
    pub plugins: Vec<PluginEntry>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct PluginEntry {
    pub name: String,
    pub source: Value,
    #[serde(default)]
    pub description: String,
}

#[derive(Deserialize)]
struct PluginManifest {
    #[serde(default)]
    description: String,
}

pub fn read_marketplace(root: &Path) -> Result<Marketplace, String> {
    read_json(&root.join(".claude-plugin/marketplace.json"))
}

fn read_json<T: for<'de> Deserialize<'de>>(file: &Path) -> Result<T, String> {
    let contents = fs::read_to_string(file)
        .map_err(|error| format!("cannot read '{}': {error}", file.display()))?;
    serde_json::from_str(&contents)
        .map_err(|error| format!("invalid JSON in '{}': {error}", file.display()))
}

pub fn plugin_dir(root: &Path, entry: &PluginEntry) -> Result<Option<PathBuf>, String> {
    match entry.source.as_str() {
        Some(source) => confined_relative_path(root, source).map(Some),
        None if entry.source.is_object() => Ok(None),
        None => Err(format!(
            "plugin '{}' has an unsupported marketplace source",
            entry.name
        )),
    }
}

pub fn describe(root: &Path, entry: &PluginEntry) -> String {
    if let Ok(Some(dir)) = plugin_dir(root, entry)
        && let Ok(manifest) = read_json::<PluginManifest>(&dir.join(".claude-plugin/plugin.json"))
        && !manifest.description.is_empty()
    {
        return manifest.description;
    }
    entry.description.clone()
}
