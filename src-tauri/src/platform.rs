use std::path::Path;
use std::process::Command;

use anyhow::{Context, Result};
use serde::Serialize;

pub fn os_name() -> &'static str {
    if cfg!(target_os = "windows") {
        "windows"
    } else if cfg!(target_os = "macos") {
        "macos"
    } else {
        "linux"
    }
}

pub fn reveal_path(path: &Path) -> Result<()> {
    let mut command = if cfg!(target_os = "windows") {
        Command::new("explorer")
    } else if cfg!(target_os = "macos") {
        Command::new("open")
    } else {
        Command::new("xdg-open")
    };

    command
        .arg(path)
        .spawn()
        .with_context(|| format!("failed to open {}", path.display()))?;

    Ok(())
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HostInfo {
    pub os: String,
    pub native_studio: bool,
    pub vinegar_available: bool,
}

#[tauri::command]
pub fn get_host_info() -> HostInfo {
    HostInfo {
        os: os_name().to_string(),
        native_studio: cfg!(target_os = "windows"),
        vinegar_available: cfg!(target_os = "linux") && crate::vinegar::detect().installed,
    }
}
