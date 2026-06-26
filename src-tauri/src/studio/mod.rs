mod api;
mod config;
pub(crate) mod engine;
mod installer;
mod model;
mod paths;
mod storage;

use std::path::PathBuf;
use std::process::Command;

use anyhow::{Context, Result};
use tauri::{AppHandle, State};
use tokio::{fs as tokio_fs, sync::Mutex};
use tracing::{info, warn};

use self::{
    config::CURRENT_CHANNEL,
    engine::apply_saved_preferences_to_install_dir,
    installer::{install_version, revalidate_version},
    model::{StudioBuild, StudioVersionsResponse},
    paths::{version_download_dir, version_executable_path, version_install_dir, version_manifest_path},
    storage::{
        discover_installed_versions, load_studio_preferences, read_installed_manifest,
        save_studio_preferences,
    },
};

pub(crate) use self::model::StudioVersionEntry;

#[derive(Default)]
pub struct StudioState {
    install_lock: Mutex<()>,
}

pub(crate) fn installed_instances(app: &AppHandle) -> Result<Vec<StudioVersionEntry>> {
    let mut versions = discover_installed_versions(app)?;
    let preferences = load_studio_preferences(app).unwrap_or_default();

    if let Some(default_version_guid) = preferences.default_version_guid.as_deref() {
        for version in versions.iter_mut() {
            if api::same_version_guid(&version.version_guid, default_version_guid) {
                version.is_default = true;
            }
        }
    }

    versions.sort_by(|left, right| {
        right
            .is_default
            .cmp(&left.is_default)
            .then_with(|| right.installed_at.cmp(&left.installed_at))
            .then_with(|| right.version.cmp(&left.version))
    });

    Ok(versions)
}

pub(crate) fn installed_studio_target(app: &AppHandle, version_guid: &str) -> Result<PathBuf> {
    let install_dir = version_install_dir(app, version_guid)?;
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        anyhow::bail!("The selected Studio version is not installed.");
    }

    Ok(install_dir)
}

#[tauri::command]
pub async fn list_studio_versions(app: AppHandle) -> Result<StudioVersionsResponse, String> {
    list_studio_versions_inner(&app)
        .await
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn install_latest_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
) -> Result<StudioVersionEntry, String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "A Studio installation is already in progress.".to_string())?;

    let version_info = api::fetch_current_version(CURRENT_CHANNEL)
        .await
        .map_err(|error| error.to_string())?;

    info!(
        channel = CURRENT_CHANNEL,
        version = %version_info.version,
        version_guid = %version_info.client_version_upload,
        "installing latest Studio version"
    );

    install_studio_version_inner(
        &app,
        &version_info.client_version_upload,
        &version_info.version,
        CURRENT_CHANNEL,
        None,
    )
    .await
    .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn install_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
    version: String,
    channel: Option<String>,
    published_at: Option<String>,
) -> Result<StudioVersionEntry, String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "A Studio installation is already in progress.".to_string())?;

    let channel = channel.unwrap_or_else(|| CURRENT_CHANNEL.to_string());

    info!(version_guid, version, channel, "installing requested Studio version");

    install_studio_version_inner(
        &app,
        &version_guid,
        &version,
        &channel,
        published_at.as_deref(),
    )
        .await
    .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn set_default_studio_version(
    app: AppHandle,
    version_guid: Option<String>,
) -> Result<(), String> {
    let mut preferences = load_studio_preferences(&app).map_err(|error| error.to_string())?;

    preferences.default_version_guid = match version_guid {
        Some(version_guid) => {
            let installed_versions = discover_installed_versions(&app).map_err(|error| error.to_string())?;
            let target_version = installed_versions
                .into_iter()
                .find(|version| {
                    version.is_installed
                        && version.executable_path.is_some()
                        && api::same_version_guid(&version.version_guid, &version_guid)
                })
                .ok_or_else(|| "The selected Studio version is not installed.".to_string())?;

            Some(target_version.version_guid)
        }
        None => None,
    };

    save_studio_preferences(&app, &preferences)
        .await
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn launch_studio(app: AppHandle, version_guid: String) -> Result<(), String> {
    let install_dir = version_install_dir(&app, &version_guid).map_err(|error| error.to_string())?;
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        return Err("The selected Studio version is not installed.".to_string());
    }

    let _manifest = read_installed_manifest(&manifest_path).map_err(|error| error.to_string())?;
    let executable_path = version_executable_path(&install_dir);

    if !executable_path.exists() {
        return Err("RobloxStudioBeta.exe was not found for the selected version.".to_string());
    }

    apply_saved_preferences_to_install_dir(&app, &install_dir)
        .await
        .map_err(|error| error.to_string())?;

    tokio::task::spawn_blocking(move || -> Result<()> {
        Command::new(&executable_path)
            .current_dir(&install_dir)
            .spawn()
            .with_context(|| format!("failed to launch {}", executable_path.display()))?;

        Ok(())
    })
    .await
    .map_err(|error| error.to_string())?
    .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn revalidate_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
) -> Result<StudioVersionEntry, String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "Cannot revalidate Studio while another installation is running.".to_string())?;

    let manifest = revalidate_version(&app, &version_guid)
        .await
        .map_err(|error| error.to_string())?;
    let install_dir = version_install_dir(&app, &manifest.version_guid).map_err(|error| error.to_string())?;
    let executable_path = version_executable_path(&install_dir);
    let mut entry = StudioVersionEntry::from_installed(
        manifest,
        &install_dir,
        executable_path.exists().then_some(executable_path),
    );

    if let Ok(latest_remote) = api::fetch_current_version(CURRENT_CHANNEL).await {
        entry.is_latest = api::same_version_guid(&latest_remote.client_version_upload, &entry.version_guid);
    } else {
        warn!(version_guid, "failed to refresh latest-version metadata after revalidation");
    }

    Ok(entry)
}

#[tauri::command]
pub async fn open_studio_install_dir(app: AppHandle, version_guid: String) -> Result<(), String> {
    let install_dir = version_install_dir(&app, &version_guid).map_err(|error| error.to_string())?;
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        return Err("The selected Studio version is not installed.".to_string());
    }

    tokio::task::spawn_blocking(move || -> Result<()> {
        Command::new("explorer")
            .arg(&install_dir)
            .spawn()
            .with_context(|| format!("failed to open {}", install_dir.display()))?;

        Ok(())
    })
    .await
    .map_err(|error| error.to_string())?
    .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn uninstall_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
) -> Result<(), String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "Cannot uninstall Studio while another installation is running.".to_string())?;

    let install_dir = version_install_dir(&app, &version_guid).map_err(|error| error.to_string())?;
    let download_dir = version_download_dir(&app, &version_guid).map_err(|error| error.to_string())?;

    if install_dir.exists() {
        tokio_fs::remove_dir_all(&install_dir)
            .await
            .map_err(|error| error.to_string())?;
    }

    if download_dir.exists() {
        let _ = tokio_fs::remove_dir_all(&download_dir).await;
    }

    let mut preferences = load_studio_preferences(&app).map_err(|error| error.to_string())?;
    if preferences
        .default_version_guid
        .as_deref()
        .map(|default_version_guid| api::same_version_guid(default_version_guid, &version_guid))
        .unwrap_or(false)
    {
        preferences.default_version_guid = None;
        save_studio_preferences(&app, &preferences)
            .await
            .map_err(|error| error.to_string())?;
    }

    Ok(())
}

async fn list_studio_versions_inner(app: &AppHandle) -> Result<StudioVersionsResponse> {
    let mut versions = discover_installed_versions(app)?;
    let preferences = load_studio_preferences(app).unwrap_or_default();
    let latest_remote = api::fetch_current_version(CURRENT_CHANNEL).await.ok();

    if let Some(latest_remote) = latest_remote.as_ref() {
        merge_remote_version(
            &mut versions,
            latest_remote.client_version_upload.clone(),
            latest_remote.version.clone(),
            CURRENT_CHANNEL,
            None,
            true,
        );
    }

    if let Ok(history) = api::fetch_build_history().await {
        for build in history {
            let is_latest = latest_remote
                .as_ref()
                .map(|latest| api::same_version_guid(&latest.client_version_upload, &build.version_guid))
                .unwrap_or(false);

            merge_history_build(&mut versions, build, is_latest);
        }
    }

    if let Some(default_version_guid) = preferences.default_version_guid.as_deref() {
        if let Some(default_version) = versions.iter_mut().find(|version| {
            version.is_installed && api::same_version_guid(&version.version_guid, default_version_guid)
        }) {
            default_version.is_default = true;
        }
    }

    versions.sort_by(|left, right| {
        right
            .is_default
            .cmp(&left.is_default)
            .then_with(|| right.is_latest.cmp(&left.is_latest))
            .then_with(|| right.is_installed.cmp(&left.is_installed))
            .then_with(|| right.published_at.cmp(&left.published_at))
            .then_with(|| right.installed_at.cmp(&left.installed_at))
            .then_with(|| right.version.cmp(&left.version))
    });

    Ok(StudioVersionsResponse { versions })
}

async fn install_studio_version_inner(
    app: &AppHandle,
    version_guid: &str,
    version: &str,
    channel: &str,
    published_at: Option<&str>,
) -> Result<StudioVersionEntry> {
    let manifest = install_version(app, version_guid, version, channel, published_at).await?;
    let install_dir = version_install_dir(app, &manifest.version_guid)?;
    let executable_path = version_executable_path(&install_dir);

    apply_saved_preferences_to_install_dir(app, &install_dir).await?;

    Ok(StudioVersionEntry::from_installed(
        manifest,
        &install_dir,
        executable_path.exists().then_some(executable_path),
    ))
}

fn merge_history_build(versions: &mut Vec<StudioVersionEntry>, build: StudioBuild, is_latest: bool) {
    merge_remote_version(
        versions,
        build.version_guid,
        build.version,
        CURRENT_CHANNEL,
        Some(build.published_at),
        is_latest,
    );
}

fn merge_remote_version(
    versions: &mut Vec<StudioVersionEntry>,
    version_guid: String,
    version: String,
    channel: &str,
    published_at: Option<String>,
    is_latest: bool,
) {
    if let Some(existing) = versions
        .iter_mut()
        .find(|entry| api::same_version_guid(&entry.version_guid, &version_guid))
    {
        existing.version = version;
        existing.channel = channel.to_string();
        existing.is_latest |= is_latest;

        if existing.published_at.is_none() {
            existing.published_at = published_at;
        }

        return;
    }

    let mut entry = StudioVersionEntry::available(version_guid, version, channel, published_at);
    entry.is_latest = is_latest;
    versions.push(entry);
}