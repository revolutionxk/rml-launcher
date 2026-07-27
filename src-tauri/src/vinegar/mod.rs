use std::{
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{bail, Context, Result};
use serde::Serialize;
use serde_json::{Map, Value};
use toml_edit::{value as toml_value, DocumentMut, Item, Table, Value as TomlValue};
use tracing::info;

use crate::{AppError, CommandResult};


const FLATPAK_APP_ID: &str = "org.vinegarhq.Vinegar";
const STUDIO_EXECUTABLE: &str = "RobloxStudioBeta.exe";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum VinegarKind {
    Binary,
    Flatpak,
    None,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VinegarStatus {
    pub installed: bool,
    pub kind: VinegarKind,
    pub flatpak_available: bool,
    pub studio_found: bool,
}

pub fn detect() -> VinegarStatus {
    let kind = detect_kind();

    VinegarStatus {
        installed: kind != VinegarKind::None,
        kind,
        flatpak_available: binary_on_path("flatpak"),
        studio_found: studio_dir_for(kind).is_ok(),
    }
}

fn detect_kind() -> VinegarKind {
    if binary_on_path("vinegar") {
        VinegarKind::Binary
    } else if flatpak_app_installed(FLATPAK_APP_ID) {
        VinegarKind::Flatpak
    } else {
        VinegarKind::None
    }
}

#[tauri::command]
pub fn vinegar_status() -> VinegarStatus {
    detect()
}

#[tauri::command]
pub async fn install_vinegar() -> CommandResult<()> {
    if !cfg!(target_os = "linux") {
        return Err(AppError::unsupported("Vinegar is only available on Linux."));
    }

    if !binary_on_path("flatpak") {
        return Err(AppError::Failed(
            "Flatpak is required to install Vinegar. Install Flatpak first.".into(),
        ));
    }

    Ok(tokio::task::spawn_blocking(install_vinegar_blocking).await??)
}

#[tauri::command]
pub async fn launch_vinegar() -> CommandResult<()> {
    if !cfg!(target_os = "linux") {
        return Err(AppError::unsupported("Vinegar is only available on Linux."));
    }

    let status = detect();
    if !status.installed {
        return Err(AppError::Failed("Vinegar is not installed.".into()));
    }

    Ok(tokio::task::spawn_blocking(move || launch_blocking(status.kind)).await??)
}

fn install_vinegar_blocking() -> Result<()> {
    info!("installing Vinegar via Flatpak");

    let status = Command::new("flatpak")
        .args(["install", "-y", "--noninteractive", "flathub", FLATPAK_APP_ID])
        .status()
        .context("failed to run flatpak to install Vinegar")?;

    if !status.success() {
        bail!("flatpak failed to install Vinegar (exit status {status})");
    }

    Ok(())
}

fn launch_blocking(kind: VinegarKind) -> Result<()> {
    let mut command = match kind {
        VinegarKind::Binary => Command::new("vinegar"),
        VinegarKind::Flatpak => {
            let mut command = Command::new("flatpak");
            command.args(["run", FLATPAK_APP_ID]);
            command
        }
        VinegarKind::None => bail!("Vinegar is not installed."),
    };

    command.spawn().context("failed to launch Vinegar")?;

    Ok(())
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
pub fn config_path() -> Option<PathBuf> {
    Some(vinegar_config_dir(detect_kind())?.join("config.toml"))
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
pub fn studio_dir() -> Result<PathBuf> {
    studio_dir_for(detect_kind())
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn studio_dir_for(kind: VinegarKind) -> Result<PathBuf> {
    if !cfg!(target_os = "linux") {
        bail!("Vinegar is only available on Linux.");
    }

    let versions = vinegar_data_dir(kind)
        .map(|data| data.join("versions"))
        .context("could not resolve the Vinegar data directory")?;

    let mut newest: Option<(std::time::SystemTime, PathBuf)> = None;

    if let Ok(entries) = std::fs::read_dir(&versions) {
        for entry in entries.flatten() {
            let dir = entry.path();
            if !dir.join(STUDIO_EXECUTABLE).is_file() {
                continue;
            }

            let modified = entry
                .metadata()
                .and_then(|metadata| metadata.modified())
                .unwrap_or(std::time::UNIX_EPOCH);

            if newest.as_ref().map(|(time, _)| modified > *time).unwrap_or(true) {
                newest = Some((modified, dir));
            }
        }
    }

    newest.map(|(_, dir)| dir).context(
        "no Roblox Studio install was found in Vinegar — launch Studio through Vinegar once first",
    )
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
pub fn set_dwmapi_override(enabled: bool) -> Result<()> {
    let path = config_path().context("could not resolve the Vinegar config directory")?;

    let mut document = if path.exists() {
        std::fs::read_to_string(&path)
            .with_context(|| format!("failed to read {}", path.display()))?
            .parse::<DocumentMut>()
            .with_context(|| format!("failed to parse {}", path.display()))?
    } else {
        DocumentMut::new()
    };

    set_dwmapi_override_in_doc(&mut document, enabled);

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    std::fs::write(&path, document.to_string())
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn set_dwmapi_override_in_doc(document: &mut DocumentMut, enabled: bool) {
    let studio = document
        .entry("studio")
        .or_insert_with(|| Item::Table(Table::new()))
        .as_table_mut()
        .expect("studio entry is a table");
    studio.set_implicit(false);

    let env = studio
        .entry("env")
        .or_insert_with(|| Item::Table(Table::new()))
        .as_table_mut()
        .expect("env entry is a table");
    env.set_implicit(false);

    let current = env.get("WINEDLLOVERRIDES").and_then(|item| item.as_str()).unwrap_or("");
    let mut entries: Vec<String> = current
        .split(';')
        .map(str::trim)
        .filter(|entry| !entry.is_empty() && !entry.starts_with("dwmapi"))
        .map(|entry| entry.to_string())
        .collect();

    if enabled {
        entries.push("dwmapi=n,b".to_string());
    }

    if entries.is_empty() {
        env.remove("WINEDLLOVERRIDES");
    } else {
        env.insert("WINEDLLOVERRIDES", toml_value(entries.join(";")));
    }
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn vinegar_config_dir(kind: VinegarKind) -> Option<PathBuf> {
    let base = if kind == VinegarKind::Flatpak {
        flatpak_home()?.join("config")
    } else {
        xdg_dir("XDG_CONFIG_HOME", ".config")?
    };

    Some(base.join("vinegar"))
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn vinegar_data_dir(kind: VinegarKind) -> Option<PathBuf> {
    let base = if kind == VinegarKind::Flatpak {
        flatpak_home()?.join("data")
    } else {
        xdg_dir("XDG_DATA_HOME", ".local/share")?
    };

    Some(base.join("vinegar"))
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn flatpak_home() -> Option<PathBuf> {
    Some(home_dir()?.join(".var/app").join(FLATPAK_APP_ID))
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn xdg_dir(env_var: &str, fallback: &str) -> Option<PathBuf> {
    std::env::var_os(env_var)
        .map(PathBuf::from)
        .or_else(|| home_dir().map(|home| home.join(fallback)))
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
pub fn apply_fflags(fflags: &Map<String, Value>) -> Result<()> {
    let Some(path) = config_path() else {
        bail!("could not resolve the Vinegar config directory");
    };

    apply_fflags_to_path(&path, fflags)
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn apply_fflags_to_path(path: &Path, fflags: &Map<String, Value>) -> Result<()> {
    let mut document = if path.exists() {
        std::fs::read_to_string(path)
            .with_context(|| format!("failed to read {}", path.display()))?
            .parse::<DocumentMut>()
            .with_context(|| format!("failed to parse {}", path.display()))?
    } else {
        DocumentMut::new()
    };

    let studio = document
        .entry("studio")
        .or_insert_with(|| Item::Table(Table::new()))
        .as_table_mut()
        .context("the Vinegar config 'studio' entry is not a table")?;
    studio.set_implicit(false);

    let mut flags_table = Table::new();
    for (name, json_value) in fflags {
        flags_table.insert(name, Item::Value(json_to_toml(json_value)));
    }
    flags_table.set_implicit(false);
    studio.insert("fflags", Item::Table(flags_table));

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    std::fs::write(path, document.to_string())
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn json_to_toml(value: &Value) -> TomlValue {
    match value {
        Value::Bool(inner) => toml_value(*inner).into_value().unwrap(),
        Value::Number(inner) => {
            if let Some(integer) = inner.as_i64() {
                toml_value(integer).into_value().unwrap()
            } else if let Some(float) = inner.as_f64() {
                toml_value(float).into_value().unwrap()
            } else {
                toml_value(inner.to_string()).into_value().unwrap()
            }
        }
        Value::String(inner) => toml_value(inner.clone()).into_value().unwrap(),
        other => toml_value(other.to_string()).into_value().unwrap(),
    }
}

fn binary_on_path(binary: &str) -> bool {
    let Some(path_var) = std::env::var_os("PATH") else {
        return false;
    };

    std::env::split_paths(&path_var).any(|dir| dir.join(binary).is_file())
}

fn flatpak_app_installed(app_id: &str) -> bool {
    Command::new("flatpak")
        .args(["info", app_id])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
fn home_dir() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

#[cfg(test)]
mod tests {
    use super::{apply_fflags_to_path, set_dwmapi_override_in_doc};
    use serde_json::json;
    use toml_edit::DocumentMut;

    #[test]
    fn toggles_dwmapi_override_preserving_other_overrides() {
        let mut document = "[studio.env]\nWINEDLLOVERRIDES = \"winhttp=n;d3d11=b\"\n"
            .parse::<DocumentMut>()
            .unwrap();

        set_dwmapi_override_in_doc(&mut document, true);
        let value = document["studio"]["env"]["WINEDLLOVERRIDES"].as_str().unwrap();
        assert!(value.contains("winhttp=n"));
        assert!(value.contains("d3d11=b"));
        assert!(value.contains("dwmapi=n,b"));

        // Disabling removes only the dwmapi entry, keeping the rest, and is idempotent.
        set_dwmapi_override_in_doc(&mut document, false);
        let value = document["studio"]["env"]["WINEDLLOVERRIDES"].as_str().unwrap();
        assert!(!value.contains("dwmapi"));
        assert!(value.contains("winhttp=n"));
    }

    #[test]
    fn removes_override_key_when_empty() {
        let mut document = DocumentMut::new();
        set_dwmapi_override_in_doc(&mut document, true);
        assert_eq!(document["studio"]["env"]["WINEDLLOVERRIDES"].as_str(), Some("dwmapi=n,b"));

        set_dwmapi_override_in_doc(&mut document, false);
        assert!(document["studio"]["env"].get("WINEDLLOVERRIDES").is_none());
    }

    #[test]
    fn writes_and_replaces_fflags_preserving_other_config() {
        let dir = std::env::temp_dir().join(format!("rml-vinegar-test-{}", std::process::id()));
        let path = dir.join("config.toml");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            &path,
            "[studio]\nrenderer = \"DXVK\"\n\n[studio.fflags]\nFFlagOld = true\n",
        )
        .unwrap();

        let mut flags = serde_json::Map::new();
        flags.insert("FFlagNew".into(), json!(true));
        flags.insert("DFIntValue".into(), json!(42));
        flags.insert("FStringName".into(), json!("hello"));

        apply_fflags_to_path(&path, &flags).unwrap();

        let written = std::fs::read_to_string(&path).unwrap();
        let document = written.parse::<toml_edit::DocumentMut>().unwrap();
        let studio = document["studio"].as_table().unwrap();

        assert_eq!(studio["renderer"].as_str(), Some("DXVK"));

        let fflags = studio["fflags"].as_table().unwrap();

        assert!(fflags.get("FFlagOld").is_none());
        assert_eq!(fflags["FFlagNew"].as_bool(), Some(true));
        assert_eq!(fflags["DFIntValue"].as_integer(), Some(42));
        assert_eq!(fflags["FStringName"].as_str(), Some("hello"));

        std::fs::remove_dir_all(&dir).ok();
    }
}
