use std::path::Path;

use anyhow::{Context, Result};

use crate::{
    store::{read_json, write_json},
    Paths,
};

use super::{
    model::{InstalledStudioManifest, StudioPreferences},
    paths::settings_path,
};

pub fn read_installed_manifest(path: &Path) -> Result<InstalledStudioManifest> {
    read_json(path)?.with_context(|| format!("{} does not contain a Studio manifest", path.display()))
}

pub fn load_studio_preferences(paths: &Paths) -> Result<StudioPreferences> {
    Ok(read_json(&settings_path(paths))?.unwrap_or_default())
}

pub async fn save_studio_preferences(paths: &Paths, preferences: &StudioPreferences) -> Result<()> {
    write_json(&settings_path(paths), preferences).await
}

pub async fn write_installed_manifest(path: &Path, manifest: &InstalledStudioManifest) -> Result<()> {
    write_json(path, manifest).await
}