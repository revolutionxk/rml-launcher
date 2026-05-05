use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use tauri::{AppHandle, Manager};

pub fn engine_root_dir(app: &AppHandle) -> Result<PathBuf> {
    let app_data_dir = app
        .path()
        .app_data_dir()
        .context("failed to resolve the app data directory")?;

    Ok(app_data_dir.join("engine"))
}

pub fn preferences_path(app: &AppHandle) -> Result<PathBuf> {
    Ok(engine_root_dir(app)?.join("settings.json"))
}

pub fn scan_cache_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(engine_root_dir(app)?.join("scans"))
}

pub fn scan_cache_path(app: &AppHandle, version_guid: &str) -> Result<PathBuf> {
    Ok(scan_cache_dir(app)?.join(format!("{version_guid}.json")))
}

pub fn client_settings_dir(install_dir: &Path) -> PathBuf {
    install_dir.join("ClientSettings")
}

pub fn client_app_settings_path(install_dir: &Path) -> PathBuf {
    client_settings_dir(install_dir).join("ClientAppSettings.json")
}

pub fn extra_content_dir(install_dir: &Path) -> PathBuf {
    install_dir.join("ExtraContent")
}