use std::env;

use anyhow::{Context, Result};
use winreg::enums::HKEY_CURRENT_USER;
use winreg::RegKey;

use super::STUDIO_SCHEMES;

fn command_path(scheme: &str) -> String {
    format!(r"Software\Classes\{scheme}\shell\open\command")
}

const BACKUP_PATH: &str = r"Software\com.revolution.rml-launcher\protocol-backup";

fn hkcu() -> RegKey {
    RegKey::predef(HKEY_CURRENT_USER)
}

fn current_command(scheme: &str) -> Option<String> {
    hkcu()
        .open_subkey(command_path(scheme))
        .ok()
        .and_then(|key| key.get_value::<String, _>("").ok())
}

fn launch_command() -> Result<String> {
    let exe = env::current_exe().context("failed to resolve the launcher executable path")?;
    Ok(format!("\"{}\" \"%1\"", exe.display()))
}

pub fn is_registered() -> Result<bool> {
    let exe = env::current_exe().context("failed to resolve the launcher executable path")?;
    let exe_display = exe.display().to_string();

    Ok(STUDIO_SCHEMES.iter().all(|scheme| {
        current_command(scheme)
            .map(|command| command.contains(&exe_display))
            .unwrap_or(false)
    }))
}

pub fn register() -> Result<()> {
    let command = launch_command()?;
    let root = hkcu();
    let (backup, _) = root
        .create_subkey(BACKUP_PATH)
        .context("failed to open the protocol backup store")?;

    for scheme in STUDIO_SCHEMES {
        if backup.get_value::<String, _>(scheme).is_err() {
            let previous = current_command(scheme).unwrap_or_default();
            backup
                .set_value(scheme, &previous)
                .with_context(|| format!("failed to back up the {scheme} handler"))?;
        }

        let (scheme_key, _) = root
            .create_subkey(format!(r"Software\Classes\{scheme}"))
            .with_context(|| format!("failed to open the {scheme} scheme key"))?;
        
        scheme_key
            .set_value("URL Protocol", &"")
            .with_context(|| format!("failed to mark {scheme} as a URL protocol"))?;

        let (command_key, _) = root
            .create_subkey(command_path(scheme))
            .with_context(|| format!("failed to open the {scheme} command key"))?;
        command_key
            .set_value("", &command)
            .with_context(|| format!("failed to set the {scheme} handler"))?;
    }

    Ok(())
}

pub fn restore() -> Result<()> {
    let root = hkcu();
    let backup = root.open_subkey(BACKUP_PATH).ok();

    for scheme in STUDIO_SCHEMES {
        let previous = backup
            .as_ref()
            .and_then(|store| store.get_value::<String, _>(scheme).ok())
            .filter(|command| !command.is_empty());

        match previous {
            Some(command) => {
                let (command_key, _) = root
                    .create_subkey(command_path(scheme))
                    .with_context(|| format!("failed to open the {scheme} command key"))?;
                command_key
                    .set_value("", &command)
                    .with_context(|| format!("failed to restore the {scheme} handler"))?;
            }
            None => {
                let _ = root.delete_subkey_all(format!(r"Software\Classes\{scheme}"));
            }
        }
    }

    let _ = root.delete_subkey_all(BACKUP_PATH);
    Ok(())
}
