use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

fn default_enable_tracking() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineOverride {
    pub value: String,
    #[serde(default)]
    pub custom: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineOverrideInput {
    pub name: String,
    pub value: String,
    #[serde(default)]
    pub custom: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct EngineStatePatch {
    #[serde(default)]
    pub replace_all: bool,
    pub enable_tracking: Option<bool>,
    pub disable_telemetry: Option<bool>,
    #[serde(default)]
    pub overrides: Vec<EngineOverrideInput>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineVersionPreferences {
    #[serde(default = "default_enable_tracking")]
    pub enable_tracking: bool,
    #[serde(default)]
    pub disable_telemetry: bool,
    #[serde(default)]
    pub overrides: BTreeMap<String, EngineOverride>,
}

impl Default for EngineVersionPreferences {
    fn default() -> Self {
        Self {
            enable_tracking: default_enable_tracking(),
            disable_telemetry: false,
            overrides: BTreeMap::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EnginePreferences {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_target_version_guid: Option<String>,
    #[serde(default)]
    pub default_profile: EngineVersionPreferences,
    #[serde(default)]
    pub version_profiles: BTreeMap<String, EngineVersionPreferences>,
}

impl Default for EnginePreferences {
    fn default() -> Self {
        Self {
            selected_target_version_guid: None,
            default_profile: EngineVersionPreferences::default(),
            version_profiles: BTreeMap::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "camelCase")]
pub enum EngineFlagSource {
    Remote,
    Binary,
    Lua,
    Custom,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScannedFlag {
    pub name: String,
    pub source: EngineFlagSource,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineScanCache {
    pub version_guid: String,
    pub version: String,
    pub scanned_at: String,
    pub flags: Vec<ScannedFlag>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineFlagRecord {
    pub name: String,
    pub source: EngineFlagSource,
    pub default_value: String,
    pub override_value: Option<String>,
    pub value: String,
    pub is_overridden: bool,
    pub is_custom: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineScanSource {
    Cached,
    Fresh,
    RemoteOnly,
    Unavailable,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineScanInfo {
    pub can_pattern_scan: bool,
    pub source: EngineScanSource,
    pub target_version_guid: Option<String>,
    pub target_version: Option<String>,
    pub last_scanned_version_guid: Option<String>,
    pub last_scanned_at: Option<String>,
    pub warning: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineTargetVersionEntry {
    pub version_guid: String,
    pub version: String,
    pub is_default: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineStateResponse {
    pub flags: Vec<EngineFlagRecord>,
    pub available_flag_count: usize,
    pub override_count: usize,
    pub enable_tracking: bool,
    pub disable_telemetry: bool,
    pub selected_target_version_guid: Option<String>,
    pub available_targets: Vec<EngineTargetVersionEntry>,
    pub scan: EngineScanInfo,
}