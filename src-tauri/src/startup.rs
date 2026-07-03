#[cfg(windows)]
use std::process::Command;

use anyhow::Result;
use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager};

use crate::CommandResult;

const BOOTSTRAP_FLAG: &str = "--bootstrap";
pub const BOOTSTRAP_REQUEST_EVENT: &str = "bootstrap-request";

fn bootstrap_flag_present<I: IntoIterator<Item = String>>(args: I) -> bool {
    args.into_iter().any(|arg| arg == BOOTSTRAP_FLAG)
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StartupOptions {
    pub bootstrap: bool,
    pub studio_uri: Option<String>,
}

#[tauri::command]
pub fn get_startup_options() -> StartupOptions {
    let args: Vec<String> = std::env::args().collect();
    let studio_uri = crate::protocol::studio_uri_from_args(args.iter().cloned());

    StartupOptions {
        bootstrap: bootstrap_flag_present(args) || studio_uri.is_some(),
        studio_uri,
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct BootstrapRequest {
    uri: Option<String>,
}

pub fn handle_second_instance(app: &AppHandle, args: Vec<String>) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.set_focus();
    }

    let uri = crate::protocol::studio_uri_from_args(args.iter().cloned());
    if uri.is_some() || bootstrap_flag_present(args) {
        let _ = app.emit(BOOTSTRAP_REQUEST_EVENT, BootstrapRequest { uri });
    }
}

#[tauri::command]
pub fn create_quick_launch_shortcut(app: AppHandle) -> CommandResult<()> {
    Ok(create_shortcut(&app)?)
}

#[cfg(windows)]
fn create_shortcut(app: &AppHandle) -> Result<()> {
    use anyhow::{bail, Context};

    let exe = std::env::current_exe().context("failed to resolve the launcher executable path")?;
    let desktop = app
        .path()
        .desktop_dir()
        .context("failed to resolve the desktop directory")?;
    let shortcut = desktop.join("Roblox Studio (RML).lnk");

    let script = format!(
        "$shell = New-Object -ComObject WScript.Shell; \
         $link = $shell.CreateShortcut('{shortcut}'); \
         $link.TargetPath = '{exe}'; \
         $link.Arguments = '{flag}'; \
         $link.IconLocation = '{exe},0'; \
         $link.Description = 'Open Roblox Studio with your mods'; \
         $link.Save()",
        shortcut = shortcut.display(),
        exe = exe.display(),
        flag = BOOTSTRAP_FLAG,
    );

    let status = Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-Command", &script])
        .status()
        .context("failed to run the shortcut creation script")?;

    if !status.success() {
        bail!("the shortcut creation script exited with an error");
    }

    Ok(())
}

#[cfg(not(windows))]
fn create_shortcut(_app: &AppHandle) -> Result<()> {
    anyhow::bail!("Desktop shortcuts are only available on Windows.")
}
