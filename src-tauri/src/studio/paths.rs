use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use tauri::{AppHandle, Manager};

pub fn studio_root_dir(app: &AppHandle) -> Result<PathBuf> {
    let app_data_dir = app
        .path()
        .app_data_dir()
        .context("failed to resolve the app data directory")?;

    Ok(app_data_dir.join("studio"))
}

pub fn versions_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(studio_root_dir(app)?.join("versions"))
}

pub fn downloads_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(studio_root_dir(app)?.join("downloads"))
}

pub fn settings_path(app: &AppHandle) -> Result<PathBuf> {
    Ok(studio_root_dir(app)?.join("settings.json"))
}

pub fn version_install_dir(app: &AppHandle, version_guid: &str) -> Result<PathBuf> {
    Ok(versions_dir(app)?.join(version_guid))
}

pub fn version_download_dir(app: &AppHandle, version_guid: &str) -> Result<PathBuf> {
    Ok(downloads_dir(app)?.join(version_guid))
}

pub fn version_manifest_path(version_dir: &Path) -> PathBuf {
    version_dir.join("rml-studio.json")
}

pub fn version_executable_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudioBeta.exe")
}