use std::fs;

use anyhow::{Context, Result};

use crate::{
    store::{read_json, write_json},
    Paths,
};

use super::{
    model::{EnginePreferences, EngineScanCache, EngineVersionPreferences},
    paths::{preferences_path, scan_cache_path},
};

pub fn load_preferences(paths: &Paths) -> Result<EnginePreferences> {
    let path = preferences_path(paths);

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
                selected_target_installation_id: None,
                default_profile: legacy_profile,
                version_profiles: Default::default(),
            }
        }
    };

    Ok(preferences)
}

pub async fn save_preferences(paths: &Paths, preferences: &EnginePreferences) -> Result<()> {
    write_json(&preferences_path(paths), preferences).await
}

pub fn load_scan_cache(paths: &Paths, version_guid: &str) -> Result<Option<EngineScanCache>> {
    read_json(&scan_cache_path(paths, version_guid))
}

pub async fn save_scan_cache(paths: &Paths, cache: &EngineScanCache) -> Result<()> {
    write_json(&scan_cache_path(paths, &cache.version_guid), cache).await
}