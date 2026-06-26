use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use tauri::{AppHandle, Manager};

pub fn modloader_root_dir(app: &AppHandle) -> Result<PathBuf> {
    let app_data_dir = app
        .path()
        .app_data_dir()
        .context("failed to resolve the app data directory")?;

    Ok(app_data_dir.join("modloader"))
}

pub fn cache_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(modloader_root_dir(app)?.join("cache"))
}

pub fn release_cache_dir(app: &AppHandle, tag: &str) -> Result<PathBuf> {
    Ok(cache_dir(app)?.join(sanitize_tag(tag)))
}

pub fn version_manifest_path(install_dir: &Path) -> PathBuf {
    install_dir.join("rml-modloader.json")
}

fn sanitize_tag(tag: &str) -> String {
    tag.chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.') {
                character
            } else {
                '_'
            }
        })
        .collect()
}
