use std::{fs, path::Path};

use anyhow::{Context, Result};
use tauri::AppHandle;
use tokio::fs as tokio_fs;

use super::{
    model::{InstalledStudioManifest, StudioPreferences, StudioVersionEntry},
    paths::{settings_path, version_executable_path, version_manifest_path, versions_dir},
};

pub fn discover_installed_versions(app: &AppHandle) -> Result<Vec<StudioVersionEntry>> {
    let versions_dir = versions_dir(app)?;

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
    let bytes = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    let manifest = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;

    Ok(manifest)
}

pub fn load_studio_preferences(app: &AppHandle) -> Result<StudioPreferences> {
    let path = settings_path(app)?;

    if !path.exists() {
        return Ok(StudioPreferences::default());
    }

    let bytes = fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
    let preferences = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;

    Ok(preferences)
}

pub async fn save_studio_preferences(app: &AppHandle, preferences: &StudioPreferences) -> Result<()> {
    let path = settings_path(app)?;

    if let Some(parent) = path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(preferences)
        .context("failed to serialize the Studio preferences")?;
    tokio_fs::write(&path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}

pub async fn write_installed_manifest(path: &Path, manifest: &InstalledStudioManifest) -> Result<()> {
    let bytes = serde_json::to_vec_pretty(manifest).context("failed to serialize the Studio manifest")?;
    tokio_fs::write(path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}