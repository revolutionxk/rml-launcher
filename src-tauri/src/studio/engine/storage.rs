use std::fs;

use anyhow::{Context, Result};
use tauri::AppHandle;
use tokio::fs as tokio_fs;

use super::{
    model::{EnginePreferences, EngineScanCache, EngineVersionPreferences},
    paths::{preferences_path, scan_cache_path},
};

pub fn load_preferences(app: &AppHandle) -> Result<EnginePreferences> {
    let path = preferences_path(app)?;

    if !path.exists() {
        return Ok(EnginePreferences::default());
    }

    let bytes = fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
    let preferences = match serde_json::from_slice::<EnginePreferences>(&bytes) {
        Ok(preferences) => preferences,
        Err(store_error) => {
            let legacy_profile = serde_json::from_slice::<EngineVersionPreferences>(&bytes)
                .with_context(|| format!("failed to parse {}", path.display()))?;

            tracing::warn!(
                path = %path.display(),
                error = %store_error,
                "migrating legacy engine settings into the version-aware format"
            );

            EnginePreferences {
                selected_target_version_guid: None,
                default_profile: legacy_profile,
                version_profiles: Default::default(),
            }
        }
    };

    Ok(preferences)
}

pub async fn save_preferences(app: &AppHandle, preferences: &EnginePreferences) -> Result<()> {
    let path = preferences_path(app)?;

    if let Some(parent) = path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(preferences)
        .context("failed to serialize engine settings")?;

    tokio_fs::write(&path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}

pub fn load_scan_cache(app: &AppHandle, version_guid: &str) -> Result<Option<EngineScanCache>> {
    let path = scan_cache_path(app, version_guid)?;

    if !path.exists() {
        return Ok(None);
    }

    let bytes = fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
    let cache = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;

    Ok(Some(cache))
}

pub async fn save_scan_cache(app: &AppHandle, cache: &EngineScanCache) -> Result<()> {
    let path = scan_cache_path(app, &cache.version_guid)?;

    if let Some(parent) = path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(cache).context("failed to serialize scan cache")?;

    tokio_fs::write(&path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}