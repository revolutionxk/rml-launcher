use std::{
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{bail, Context, Result};
use serde::Serialize;
use serde_json::{Map, Value};
use toml_edit::{value as toml_value, DocumentMut, Item, Table, Value as TomlValue};
use tracing::info;

const FLATPAK_APP_ID: &str = "org.vinegarhq.Vinegar";

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
}

pub fn detect() -> VinegarStatus {
    let kind = if binary_on_path("vinegar") {
        VinegarKind::Binary
    } else if flatpak_app_installed(FLATPAK_APP_ID) {
        VinegarKind::Flatpak
    } else {
        VinegarKind::None
    };

    VinegarStatus {
        installed: kind != VinegarKind::None,
        kind,
        flatpak_available: binary_on_path("flatpak"),
    }
}

#[tauri::command]
pub fn vinegar_status() -> VinegarStatus {
    detect()
}

#[tauri::command]
pub async fn install_vinegar() -> Result<(), String> {
    if !cfg!(target_os = "linux") {
        return Err("Vinegar is only available on Linux.".to_string());
    }

    if !binary_on_path("flatpak") {
        return Err("Flatpak is required to install Vinegar. Install Flatpak first.".to_string());
    }

    tokio::task::spawn_blocking(install_vinegar_blocking)
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn launch_vinegar() -> Result<(), String> {
    if !cfg!(target_os = "linux") {
        return Err("Vinegar is only available on Linux.".to_string());
    }

    let status = detect();
    if !status.installed {
        return Err("Vinegar is not installed.".to_string());
    }

    tokio::task::spawn_blocking(move || launch_blocking(status.kind))
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
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
    let home = home_dir()?;

    let flatpak = home
        .join(".var/app")
        .join(FLATPAK_APP_ID)
        .join("config/vinegar/config.toml");
    if flatpak.exists() {
        return Some(flatpak);
    }

    let xdg = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".config"))
        .join("vinegar/config.toml");

    Some(xdg)
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
    use super::apply_fflags_to_path;
    use serde_json::json;

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
