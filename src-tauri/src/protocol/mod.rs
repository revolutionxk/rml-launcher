#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod registry;
#[cfg(target_os = "windows")]
mod windows;

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
mod unsupported;

use anyhow::Result;
use serde::Serialize;

use crate::CommandResult;

pub const STUDIO_SCHEMES: [&str; 2] = ["roblox-studio-auth", "roblox-studio"];

pub fn studio_uri_from_args<I>(args: I) -> Option<String>
where
    I: IntoIterator<Item = String>,
{
    args.into_iter().find(|arg| is_studio_uri(arg))
}

pub fn is_studio_uri(arg: &str) -> bool {
    let lowercased = arg.to_ascii_lowercase();
    STUDIO_SCHEMES
        .iter()
        .any(|scheme| lowercased.starts_with(&format!("{scheme}:")))
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProtocolStatus {
    pub supported: bool,
    pub enabled: bool,
}

pub trait ProtocolHandler {
    fn status(&self) -> ProtocolStatus;
    fn register(&self) -> Result<()>;
    fn restore(&self) -> Result<()>;
}

fn active_handler() -> impl ProtocolHandler {
    #[cfg(target_os = "windows")]
    {
        windows::WindowsProtocolHandler
    }
    #[cfg(target_os = "macos")]
    {
        macos::MacosProtocolHandler
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos")))]
    {
        unsupported::UnsupportedProtocolHandler
    }
}

#[tauri::command]
pub fn studio_protocol_status() -> ProtocolStatus {
    active_handler().status()
}

#[tauri::command]
pub fn set_studio_protocol_handler(enabled: bool) -> CommandResult<ProtocolStatus> {
    let handler = active_handler();

    if enabled {
        handler.register()?;
    } else {
        handler.restore()?;
    }

    Ok(handler.status())
}
