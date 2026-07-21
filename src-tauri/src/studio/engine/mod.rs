mod model;
mod paths;
mod scanner;
mod storage;

use std::{
    collections::BTreeMap,
    path::Path,
};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use serde::Deserialize;
use serde_json::{Map, Number, Value};
use tauri::AppHandle;
use tokio::fs as tokio_fs;

use crate::{AppError, CommandResult, Paths};

use super::{
    installation::{self, Capabilities, StudioInstallation},
    storage::load_studio_preferences,
};

use self::{
    model::{
        EngineFlagRecord, EngineFlagSource, EngineOverride, EngineOverrideInput,
        EnginePreferences, EngineScanCache, EngineScanInfo, EngineScanSource,
        EngineStatePatch, EngineStateResponse, EngineTargetVersionEntry,
        EngineVersionPreferences,
    },
    paths as engine_paths,
    scanner::scan_install_flags,
    storage::{load_preferences, load_scan_cache, save_preferences, save_scan_cache},
};

const REMOTE_CLIENT_SETTINGS_URL: &str =
    "https://clientsettingscdn.roblox.com/v2/settings/application/PCDesktopClient";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RemoteClientSettingsResponse {
    application_settings: BTreeMap<String, Value>,
}

#[derive(Debug)]
struct CatalogEntry {
    source: EngineFlagSource,
    default_value: String,
    is_custom: bool,
}

#[tauri::command]
pub async fn get_engine_state(app: AppHandle) -> CommandResult<EngineStateResponse> {
    let paths = Paths::resolve(&app)?;
    Ok(build_engine_state(&paths, false).await?)
}

#[tauri::command]
pub async fn rescan_engine_flags(app: AppHandle) -> CommandResult<EngineStateResponse> {
    let paths = Paths::resolve(&app)?;
    Ok(build_engine_state(&paths, true).await?)
}

#[tauri::command]
pub async fn set_engine_target_version(
    app: AppHandle,
    installation_id: Option<String>,
) -> CommandResult<EngineStateResponse> {
    let paths = Paths::resolve(&app)?;
    let mut preferences = load_preferences(&paths)?;

    preferences.selected_target_installation_id = match installation_id {
        Some(installation_id) => {
            let installed_targets = resolve_installed_targets(&paths)?;
            let target = installed_targets
                .into_iter()
                .find(|target| target.id.as_str() == installation_id)
                .ok_or_else(|| {
                    AppError::Failed("The selected Studio engine target is not installed.".into())
                })?;

            Some(target.id.to_string())
        }
        None => None,
    };

    save_preferences(&paths, &preferences).await?;

    Ok(build_engine_state(&paths, false).await?)
}

#[tauri::command]
pub async fn apply_engine_state_patch(
    app: AppHandle,
    patch: EngineStatePatch,
) -> CommandResult<EngineStateResponse> {
    let paths = Paths::resolve(&app)?;
    let normalized_overrides = patch
        .overrides
        .into_iter()
        .map(normalize_override_input)
        .collect::<Result<Vec<_>>>()?;
    let mut preferences = load_preferences(&paths)?;
    let active_target_guid = resolve_active_target_guid(&paths, &preferences)?;
    let profile = active_profile_mut(&mut preferences, active_target_guid.as_deref());

    if patch.replace_all {
        profile.overrides.clear();
    }

    if let Some(enable_tracking) = patch.enable_tracking {
        profile.enable_tracking = enable_tracking;
    }

    if let Some(disable_telemetry) = patch.disable_telemetry {
        profile.disable_telemetry = disable_telemetry;
    }

    for (name, override_entry) in normalized_overrides {
        profile.overrides.insert(name, override_entry);
    }

    save_preferences(&paths, &preferences).await?;
    sync_preferences_to_installed_versions(&paths, &preferences).await?;

    Ok(build_engine_state(&paths, false).await?)
}

#[tauri::command]
pub async fn upsert_engine_flag_override(
    app: AppHandle,
    name: String,
    value: String,
    custom: Option<bool>,
) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let normalized_name = normalize_flag_name(&name)?;
    let normalized_value = normalize_flag_value(&normalized_name, &value)?;
    let mut preferences = load_preferences(&paths)?;
    let active_target_guid = resolve_active_target_guid(&paths, &preferences)?;
    let profile = active_profile_mut(&mut preferences, active_target_guid.as_deref());

    profile.overrides.insert(
        normalized_name,
        EngineOverride {
            value: normalized_value,
            custom: custom.unwrap_or(false),
        },
    );

    save_preferences(&paths, &preferences).await?;
    Ok(sync_preferences_to_installed_versions(&paths, &preferences).await?)
}

#[tauri::command]
pub async fn remove_engine_flag_override(app: AppHandle, name: String) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let normalized_name = normalize_flag_name(&name)?;
    let mut preferences = load_preferences(&paths)?;
    let active_target_guid = resolve_active_target_guid(&paths, &preferences)?;
    let profile = active_profile_mut(&mut preferences, active_target_guid.as_deref());
    profile.overrides.remove(&normalized_name);

    save_preferences(&paths, &preferences).await?;
    Ok(sync_preferences_to_installed_versions(&paths, &preferences).await?)
}

#[tauri::command]
pub async fn clear_engine_flag_overrides(app: AppHandle) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let mut preferences = load_preferences(&paths)?;
    let active_target_guid = resolve_active_target_guid(&paths, &preferences)?;
    let profile = active_profile_mut(&mut preferences, active_target_guid.as_deref());
    profile.overrides.clear();

    save_preferences(&paths, &preferences).await?;
    Ok(sync_preferences_to_installed_versions(&paths, &preferences).await?)
}

#[tauri::command]
pub async fn set_engine_general_settings(
    app: AppHandle,
    enable_tracking: bool,
    disable_telemetry: bool,
) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let mut preferences = load_preferences(&paths)?;
    let active_target_guid = resolve_active_target_guid(&paths, &preferences)?;
    let profile = active_profile_mut(&mut preferences, active_target_guid.as_deref());
    profile.enable_tracking = enable_tracking;
    profile.disable_telemetry = disable_telemetry;

    save_preferences(&paths, &preferences).await?;
    Ok(sync_preferences_to_installed_versions(&paths, &preferences).await?)
}

pub(crate) async fn apply_saved_preferences_to_install_dir(
    paths: &Paths,
    install_dir: &Path,
) -> Result<()> {
    let preferences = load_preferences(paths)?;
    let target_id = installation_id_for_install_dir(paths, install_dir);
    let profile = active_profile(&preferences, target_id.as_deref());

    apply_preferences_to_install_dir(install_dir, profile).await
}

async fn build_engine_state(paths: &Paths, force_rescan: bool) -> Result<EngineStateResponse> {
    let preferences = load_preferences(paths)?;
    let remote_defaults = fetch_remote_defaults().await.unwrap_or_default();
    let installed_targets = resolve_installed_targets(paths)?;
    let target = resolve_target_version(paths, &preferences, &installed_targets);
    let active_profile = active_profile(&preferences, target.as_ref().map(|entry| entry.id.as_str()));
    let selected_target_installation_id = preferences
        .selected_target_installation_id
        .as_ref()
        .and_then(|selected_id| {
            installed_targets
                .iter()
                .find(|target| target.id.as_str() == selected_id)
                .map(|target| target.id.to_string())
        });
    let mut warning = None;
    let mut scan_source = if remote_defaults.is_empty() {
        EngineScanSource::Unavailable
    } else {
        EngineScanSource::RemoteOnly
    };
    let mut last_scanned_at = None;
    let mut last_scanned_version_guid = None;
    let mut scanned_flags = Vec::new();

    if let Some(target) = target.as_ref() {
        match get_scan_cache_for_target(paths, target, force_rescan).await {
            Ok(Some(cache)) => {
                last_scanned_at = Some(cache.scanned_at.clone());
                last_scanned_version_guid = Some(cache.version_guid.clone());
                scanned_flags = cache.flags;
                scan_source = if force_rescan {
                    EngineScanSource::Fresh
                } else {
                    EngineScanSource::Cached
                };
            }
            Ok(None) => {}
            Err(error) => {
                warning = Some(error.to_string());
                scan_source = if remote_defaults.is_empty() {
                    EngineScanSource::Unavailable
                } else {
                    EngineScanSource::RemoteOnly
                };
            }
        }
    }

    let flags = build_flag_records(&remote_defaults, scanned_flags, &active_profile.overrides);
    let available_targets = installed_targets
        .iter()
        .map(|target_entry| EngineTargetVersionEntry {
            id: target_entry.id.to_string(),
            version: target_entry.version.clone().unwrap_or_default(),
            is_default: is_default_target(paths, target_entry),
        })
        .collect::<Vec<_>>();

    Ok(EngineStateResponse {
        available_flag_count: flags.len(),
        override_count: active_profile.overrides.len(),
        enable_tracking: active_profile.enable_tracking,
        disable_telemetry: active_profile.disable_telemetry,
        selected_target_installation_id,
        available_targets,
        scan: EngineScanInfo {
            can_pattern_scan: target.is_some(),
            source: scan_source,
            target_installation_id: target.as_ref().map(|entry| entry.id.to_string()),
            target_version: target.as_ref().and_then(|entry| entry.version.clone()),
            last_scanned_version_guid,
            last_scanned_at,
            warning,
        },
        flags,
    })
}

fn build_flag_records(
    remote_defaults: &BTreeMap<String, String>,
    scanned_flags: Vec<model::ScannedFlag>,
    overrides: &BTreeMap<String, EngineOverride>,
) -> Vec<EngineFlagRecord> {
    let mut catalog = BTreeMap::<String, CatalogEntry>::new();

    for (name, value) in remote_defaults {
        catalog.insert(
            name.clone(),
            CatalogEntry {
                source: EngineFlagSource::Remote,
                default_value: value.clone(),
                is_custom: false,
            },
        );
    }

    for scanned_flag in scanned_flags {
        catalog.entry(scanned_flag.name.clone()).or_insert_with(|| CatalogEntry {
            source: scanned_flag.source,
            default_value: infer_default_value(&scanned_flag.name, None),
            is_custom: false,
        });
    }

    for (name, override_entry) in overrides {
        catalog
            .entry(name.clone())
            .and_modify(|entry| {
                if override_entry.custom {
                    entry.is_custom = true;
                    entry.source = EngineFlagSource::Custom;
                }
            })
            .or_insert_with(|| CatalogEntry {
                source: EngineFlagSource::Custom,
                default_value: infer_default_value(name, None),
                is_custom: true,
            });
    }

    let mut flags = catalog
        .into_iter()
        .map(|(name, entry)| {
            let override_value = overrides.get(&name).map(|entry| entry.value.clone());
            let effective_value = override_value
                .clone()
                .unwrap_or_else(|| entry.default_value.clone());
            let is_overridden = overrides.contains_key(&name);

            EngineFlagRecord {
                source: entry.source,
                name,
                default_value: entry.default_value,
                override_value,
                value: effective_value,
                is_overridden,
                is_custom: entry.is_custom,
            }
        })
        .collect::<Vec<_>>();

    flags.sort_by(|left, right| {
        right
            .is_overridden
            .cmp(&left.is_overridden)
            .then_with(|| left.name.cmp(&right.name))
    });

    flags
}

fn scan_cache_key(installation: &StudioInstallation) -> String {
    installation
        .version_guid
        .clone()
        .unwrap_or_else(|| installation.id.as_str().replace([':', '/', '\\'], "_"))
}

async fn get_scan_cache_for_target(
    paths: &Paths,
    target: &StudioInstallation,
    force_rescan: bool,
) -> Result<Option<EngineScanCache>> {
    if !force_rescan {
        if let Some(cache) = load_scan_cache(paths, &scan_cache_key(target))? {
            return Ok(Some(cache));
        }
    }

    let install_dir = target.install_dir.clone();
    let executable_path = target.executable.clone();
    let flags = tokio::task::spawn_blocking(move || scan_install_flags(&install_dir, &executable_path))
        .await
        .context("engine flag scan task failed to join")??;

    let cache = EngineScanCache {
        version_guid: scan_cache_key(target),
        version: target.version.clone().unwrap_or_default(),
        scanned_at: Utc::now().to_rfc3339(),
        flags,
    };

    save_scan_cache(paths, &cache).await?;

    Ok(Some(cache))
}

async fn fetch_remote_defaults() -> Result<BTreeMap<String, String>> {
    let response = reqwest::Client::builder()
        .user_agent("RML Launcher/0.1.0")
        .build()
        .context("failed to build the remote flag client")?
        .get(REMOTE_CLIENT_SETTINGS_URL)
        .send()
        .await
        .context("failed to fetch the remote fast flag defaults")?
        .error_for_status()
        .context("Roblox returned an error while fetching remote fast flag defaults")?
        .json::<RemoteClientSettingsResponse>()
        .await
        .context("failed to parse the remote fast flag defaults")?;

    Ok(response
        .application_settings
        .into_iter()
        .filter(|(name, _)| !name.ends_with("_PlaceFilter"))
        .map(|(name, value)| (name, stringify_setting_value(&value)))
        .collect())
}

fn stringify_setting_value(value: &Value) -> String {
    match value {
        Value::String(inner) => inner.clone(),
        Value::Bool(inner) => inner.to_string(),
        Value::Number(inner) => inner.to_string(),
        Value::Null => String::new(),
        Value::Array(_) | Value::Object(_) => value.to_string(),
    }
}

fn resolve_installed_targets(paths: &Paths) -> Result<Vec<StudioInstallation>> {
    let mut targets: Vec<StudioInstallation> = installation::discover(paths)
        .into_iter()
        .filter(|target| {
            target.capabilities.contains(Capabilities::ENGINE_FLAGS) && target.executable.exists()
        })
        .collect();

    targets.sort_by(|left, right| {
        right
            .installed_at
            .cmp(&left.installed_at)
            .then_with(|| right.version.cmp(&left.version))
    });

    Ok(targets)
}

fn is_default_target(paths: &Paths, target: &StudioInstallation) -> bool {
    load_studio_preferences(paths)
        .unwrap_or_default()
        .default_installation_id
        .as_deref()
        == Some(target.id.as_str())
}

fn resolve_target_version(
    paths: &Paths,
    preferences: &EnginePreferences,
    installed_targets: &[StudioInstallation],
) -> Option<StudioInstallation> {
    if let Some(selected_id) = preferences.selected_target_installation_id.as_deref() {
        if let Some(target) = installed_targets
            .iter()
            .find(|target| target.id.as_str() == selected_id)
        {
            return Some(target.clone());
        }
    }

    if let Some(default_target) = installed_targets
        .iter()
        .find(|target| is_default_target(paths, target))
    {
        return Some(default_target.clone());
    }

    installed_targets.first().cloned()
}

fn resolve_active_target_guid(paths: &Paths, preferences: &EnginePreferences) -> Result<Option<String>> {
    let installed_targets = resolve_installed_targets(paths)?;

    Ok(resolve_target_version(paths, preferences, &installed_targets)
        .map(|target| target.id.to_string()))
}

fn active_profile<'a>(
    preferences: &'a EnginePreferences,
    target_version_guid: Option<&str>,
) -> &'a EngineVersionPreferences {
    target_version_guid
        .and_then(|target_version_guid| preferences.version_profiles.get(target_version_guid))
        .unwrap_or(&preferences.default_profile)
}

fn active_profile_mut<'a>(
    preferences: &'a mut EnginePreferences,
    target_version_guid: Option<&str>,
) -> &'a mut EngineVersionPreferences {
    if let Some(target_version_guid) = target_version_guid {
        let fallback_profile = preferences
            .version_profiles
            .get(target_version_guid)
            .cloned()
            .unwrap_or_else(|| preferences.default_profile.clone());

        return preferences
            .version_profiles
            .entry(target_version_guid.to_string())
            .or_insert(fallback_profile);
    }

    &mut preferences.default_profile
}

async fn sync_preferences_to_installed_versions(
    paths: &Paths,
    preferences: &EnginePreferences,
) -> Result<()> {
    for target in resolve_installed_targets(paths)? {
        let profile = active_profile(preferences, Some(target.id.as_str()));
        apply_preferences_to_install_dir(&target.install_dir, profile).await?;
    }

    sync_preferences_to_vinegar(preferences);

    Ok(())
}

#[cfg(target_os = "linux")]
fn sync_preferences_to_vinegar(preferences: &EnginePreferences) {
    if !crate::vinegar::detect().installed {
        return;
    }

    let profile = active_profile(preferences, None);
    match build_flag_value_map(profile) {
        Ok(fflags) => {
            if let Err(error) = crate::vinegar::apply_fflags(&fflags) {
                tracing::warn!(error = %error, "failed to sync Fast Flags to Vinegar");
            }
        }
        Err(error) => tracing::warn!(error = %error, "failed to build Fast Flags for Vinegar"),
    }
}

#[cfg(not(target_os = "linux"))]
fn sync_preferences_to_vinegar(_preferences: &EnginePreferences) {}

async fn apply_preferences_to_install_dir(
    install_dir: &Path,
    profile: &EngineVersionPreferences,
) -> Result<()> {
    let client_settings_path = engine_paths::client_app_settings_path(install_dir);

    if profile.overrides.is_empty() {
        if client_settings_path.exists() {
            tokio_fs::remove_file(&client_settings_path)
                .await
                .with_context(|| format!("failed to remove {}", client_settings_path.display()))?;
        }

        return Ok(());
    }

    let client_settings_dir = engine_paths::client_settings_dir(install_dir);
    tokio_fs::create_dir_all(&client_settings_dir)
        .await
        .with_context(|| format!("failed to create {}", client_settings_dir.display()))?;

    let bytes = build_client_app_settings(profile)?;
    tokio_fs::write(&client_settings_path, bytes)
        .await
        .with_context(|| format!("failed to write {}", client_settings_path.display()))?;

    Ok(())
}

fn build_flag_value_map(profile: &EngineVersionPreferences) -> Result<Map<String, Value>> {
    let mut json = Map::new();

    for (name, override_entry) in &profile.overrides {
        json.insert(
            name.clone(),
            serialize_override_value(name, &override_entry.value)?,
        );
    }

    Ok(json)
}

fn build_client_app_settings(profile: &EngineVersionPreferences) -> Result<Vec<u8>> {
    let json = build_flag_value_map(profile)?;

    serde_json::to_vec_pretty(&Value::Object(json)).context("failed to serialize ClientAppSettings.json")
}

fn serialize_override_value(name: &str, value: &str) -> Result<Value> {
    let normalized_value = normalize_flag_value(name, value)?;

    Ok(match infer_value_kind(name, &normalized_value) {
        FlagValueKind::Boolean => Value::Bool(normalized_value == "true"),
        FlagValueKind::Integer => {
            let parsed = normalized_value
                .parse::<i64>()
                .with_context(|| format!("{name} expected an integer value"))?;
            Value::Number(Number::from(parsed))
        }
        FlagValueKind::String => Value::String(normalized_value),
    })
}

fn normalize_flag_name(name: &str) -> Result<String> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        bail!("flag name cannot be empty");
    }

    Ok(trimmed.to_string())
}

fn normalize_flag_value(name: &str, value: &str) -> Result<String> {
    let trimmed = value.trim();

    match infer_value_kind(name, trimmed) {
        FlagValueKind::Boolean => match trimmed.to_ascii_lowercase().as_str() {
            "true" => Ok("true".to_string()),
            "false" => Ok("false".to_string()),
            _ => bail!("{name} expects a boolean value"),
        },
        FlagValueKind::Integer => {
            let parsed = trimmed
                .parse::<i64>()
                .with_context(|| format!("{name} expects an integer value"))?;
            Ok(parsed.to_string())
        }
        FlagValueKind::String => Ok(value.to_string()),
    }
}

fn infer_default_value(name: &str, current: Option<&str>) -> String {
    match current {
        Some(value) => stringify_setting_value(&Value::String(value.to_string())),
        None => match infer_value_kind(name, "") {
            FlagValueKind::Boolean => "false".to_string(),
            FlagValueKind::Integer => "0".to_string(),
            FlagValueKind::String => String::new(),
        },
    }
}

fn installation_id_for_install_dir(paths: &Paths, install_dir: &Path) -> Option<String> {
    installation::discover(paths)
        .into_iter()
        .find(|candidate| candidate.install_dir == install_dir)
        .map(|candidate| candidate.id.to_string())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FlagValueKind {
    Boolean,
    Integer,
    String,
}

fn infer_value_kind(name: &str, value: &str) -> FlagValueKind {
    let trimmed_name = name.trim();
    let trimmed_value = value.trim();

    if trimmed_name.starts_with("FFlag")
        || trimmed_name.starts_with("DFFlag")
        || trimmed_name.starts_with("SFFlag")
    {
        return FlagValueKind::Boolean;
    }

    if trimmed_name.starts_with("FInt")
        || trimmed_name.starts_with("DFInt")
        || trimmed_name.starts_with("SFInt")
        || trimmed_name.starts_with("FLog")
        || trimmed_name.starts_with("DFLog")
        || trimmed_name.starts_with("SFLog")
    {
        return FlagValueKind::Integer;
    }

    if trimmed_value.eq_ignore_ascii_case("true") || trimmed_value.eq_ignore_ascii_case("false") {
        return FlagValueKind::Boolean;
    }

    if !trimmed_value.is_empty() && trimmed_value.parse::<i64>().is_ok() {
        return FlagValueKind::Integer;
    }

    FlagValueKind::String
}

fn normalize_override_input(input: EngineOverrideInput) -> Result<(String, EngineOverride)> {
    let normalized_name = normalize_flag_name(&input.name)?;
    let normalized_value = normalize_flag_value(&normalized_name, &input.value)?;

    Ok((
        normalized_name,
        EngineOverride {
            value: normalized_value,
            custom: input.custom,
        },
    ))
}
