#[cfg(windows)]
mod registry;

use serde::Serialize;

use crate::CommandResult;
#[cfg(not(windows))]
use crate::AppError;

const STUDIO_SCHEMES: [&str; 2] = ["roblox-studio-auth", "roblox-studio"];

pub fn studio_uri_from_args<I>(args: I) -> Option<String>
where
    I: IntoIterator<Item = String>,
{
    args.into_iter().find(|arg| is_studio_uri(arg))
}

fn is_studio_uri(arg: &str) -> bool {
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

impl ProtocolStatus {
    #[cfg(windows)]
    fn current() -> Self {
        Self {
            supported: true,
            enabled: registry::is_registered().unwrap_or(false),
        }
    }

    #[cfg(not(windows))]
    fn current() -> Self {
        Self {
            supported: false,
            enabled: false,
        }
    }
}

#[tauri::command]
pub fn studio_protocol_status() -> ProtocolStatus {
    ProtocolStatus::current()
}

#[tauri::command]
pub fn set_studio_protocol_handler(enabled: bool) -> CommandResult<ProtocolStatus> {
    #[cfg(windows)]
    {
        if enabled {
            registry::register()
        } else {
            registry::restore()
        }?;

        Ok(ProtocolStatus::current())
    }

    #[cfg(not(windows))]
    {
        let _ = enabled;
        Err(AppError::unsupported(
            "Opening Studio links through RML is only available on Windows.",
        ))
    }
}
