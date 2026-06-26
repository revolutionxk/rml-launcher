use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModEntry {
    pub id: String,
    pub name: String,
    pub enabled: bool,
    pub size_bytes: u64,
    pub kinds: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModsResponse {
    pub loader_installed: bool,
    pub mods: Vec<ModEntry>,
}
