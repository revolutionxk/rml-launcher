use std::{fs, path::Path};

use anyhow::{Context, Result};

use crate::{
    store::{read_json, write_json},
    Paths,
};

use super::{
    model::{InstalledStudioManifest, StudioPreferences, StudioVersionEntry},
    paths::{settings_path, version_executable_path, version_manifest_path, versions_dir},
};

pub fn discover_installed_versions(paths: &Paths) -> Result<Vec<StudioVersionEntry>> {
    let versions_dir = versions_dir(paths);

    if !versions_dir.exists() {
        return Ok(Vec::new());
    }

    let mut versions = Vec::new();

    for entry in fs::read_dir(&versions_dir).context("failed to enumerate installed Studio versions")? {
        let entry = entry?;
        let file_type = entry.file_type()?;

        if !file_type.is_dir() {
            continue;
        }

        let install_dir = entry.path();
        let manifest_path = version_manifest_path(&install_dir);

        if !manifest_path.exists() {
            continue;
        }

        let manifest = match read_installed_manifest(&manifest_path) {
            Ok(manifest) => manifest,
            Err(_) => continue,
        };

        let executable_path = version_executable_path(&install_dir);

        versions.push(StudioVersionEntry::from_installed(
            manifest,
            &install_dir,
            executable_path.exists().then_some(executable_path),
        ));
    }

    Ok(versions)
}

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