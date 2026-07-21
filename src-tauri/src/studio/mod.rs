mod api;
mod config;
mod deployment;
mod launch;
mod progress;
pub(crate) mod engine;
#[cfg(not(target_os = "macos"))]
mod installer;
mod model;
mod paths;
mod storage;

use std::path::PathBuf;

use anyhow::{bail, Context, Result};
use tauri::{AppHandle, Emitter, State};
use tokio::{fs as tokio_fs, sync::Mutex};
use tracing::info;
#[cfg(not(target_os = "macos"))]
use tracing::warn;

use crate::{AppError, CommandResult, Paths};

use self::{
    config::{CURRENT_CHANNEL, STUDIO_INSTALL_EVENT},
    engine::apply_saved_preferences_to_install_dir,
    deployment::{active_deployment, StudioDeployment},
    launch::{active_launcher, StudioLauncher},
    progress::StudioProgressSink,
    model::{StudioBuild, StudioInstallProgress, StudioVersionsResponse},
    paths::{
        version_download_dir, version_executable_path, version_install_dir, version_manifest_path,
    },
    storage::{
        discover_installed_versions, load_studio_preferences, read_installed_manifest,
        save_studio_preferences,
    },
};

#[cfg(not(target_os = "macos"))]
use self::installer::revalidate_version;

#[cfg(not(target_os = "macos"))]
use self::paths::downloads_dir;

pub(crate) use self::model::StudioVersionEntry;

#[derive(Default)]
pub struct StudioState {
    install_lock: Mutex<()>,
}

struct EventSink<'a> {
    app: &'a AppHandle,
}

impl StudioProgressSink for EventSink<'_> {
    fn report(&self, progress: StudioInstallProgress) {
        let _ = self.app.emit(STUDIO_INSTALL_EVENT, progress);
    }
}

pub(crate) fn installed_instances(app: &AppHandle) -> Result<Vec<StudioVersionEntry>> {
    let paths = Paths::resolve(app)?;
    let mut versions = discover_installed_versions(&paths)?;
    let preferences = load_studio_preferences(&paths).unwrap_or_default();

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
    if version_guid == crate::vinegar::INSTANCE_ID {
        return crate::vinegar::studio_dir();
    }

    let paths = Paths::resolve(app)?;
    let install_dir = version_install_dir(&paths, version_guid);
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        anyhow::bail!("The selected Studio version is not installed.");
    }

    Ok(install_dir)
}

#[tauri::command]
pub async fn list_studio_versions(app: AppHandle) -> CommandResult<StudioVersionsResponse> {
    Ok(list_studio_versions_inner(&app).await?)
}

#[tauri::command]
pub async fn install_latest_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A Studio installation is already in progress.".into()))?;

    let version_info = api::fetch_current_version(CURRENT_CHANNEL).await?;

    info!(
        channel = CURRENT_CHANNEL,
        version = %version_info.version,
        version_guid = %version_info.client_version_upload,
        "installing latest Studio version"
    );

    Ok(install_studio_version_inner(
        &app,
        &version_info.client_version_upload,
        &version_info.version,
        CURRENT_CHANNEL,
        None,
    )
    .await?)
}

#[tauri::command]
pub async fn install_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
    version: String,
    channel: Option<String>,
    published_at: Option<String>,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A Studio installation is already in progress.".into()))?;

    let channel = channel.unwrap_or_else(|| CURRENT_CHANNEL.to_string());

    info!(version_guid, version, channel, "installing requested Studio version");

    Ok(install_studio_version_inner(&app, &version_guid, &version, &channel, published_at.as_deref())
        .await?)
}

#[tauri::command]
pub async fn set_default_studio_version(
    app: AppHandle,
    version_guid: Option<String>,
) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let mut preferences = load_studio_preferences(&paths)?;

    preferences.default_version_guid = match version_guid {
        Some(version_guid) => {
            let installed_versions = discover_installed_versions(&paths)?;
            let target_version = installed_versions
                .into_iter()
                .find(|version| {
                    version.is_installed
                        && version.executable_path.is_some()
                        && api::same_version_guid(&version.version_guid, &version_guid)
                })
                .ok_or_else(|| {
                    AppError::Failed("The selected Studio version is not installed.".into())
                })?;

            Some(target_version.version_guid)
        }
        None => None,
    };

    Ok(save_studio_preferences(&paths, &preferences).await?)
}

#[tauri::command]
pub async fn launch_studio(
    app: AppHandle,
    version_guid: String,
    uri: Option<String>,
) -> CommandResult<()> {
    Ok(launch_studio_inner(&app, &version_guid, uri.as_deref()).await?)
}

async fn launch_studio_inner(app: &AppHandle, version_guid: &str, uri: Option<&str>) -> Result<()> {
    let paths = Paths::resolve(app)?;
    let install_dir = version_install_dir(&paths, version_guid);
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        bail!("The selected Studio version is not installed.");
    }

    read_installed_manifest(&manifest_path)?;
    apply_saved_preferences_to_install_dir(&paths, &install_dir).await?;

    let uri = uri.map(str::to_string);
    tokio::task::spawn_blocking(move || active_launcher().launch(&install_dir, uri.as_deref()))
        .await
        .context("the Studio launch task failed to join")?
}

#[tauri::command]
pub async fn revalidate_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state.install_lock.try_lock().map_err(|_| {
        AppError::Failed("Cannot revalidate Studio while another installation is running.".into())
    })?;

    #[cfg(target_os = "macos")]
    {
        let _ = (&app, &version_guid);
        return Err(AppError::unsupported(
            "Revalidation is not available for macOS Studio yet.",
        ));
    }

    #[cfg(not(target_os = "macos"))]
    {
    let paths = Paths::resolve(&app)?;
    let install_dir = version_install_dir(&paths, &version_guid);
    let downloads_root = downloads_dir(&paths);
    let manifest = revalidate_version(install_dir, downloads_root, &version_guid).await?;
    let install_dir = version_install_dir(&paths, &manifest.version_guid);
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
}

#[tauri::command]
pub async fn open_studio_install_dir(app: AppHandle, version_guid: String) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let install_dir = version_install_dir(&paths, &version_guid);
    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        return Err(AppError::Failed(
            "The selected Studio version is not installed.".into(),
        ));
    }

    Ok(crate::platform::reveal_path(&install_dir)?)
}

#[tauri::command]
pub async fn uninstall_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
) -> CommandResult<()> {
    let _guard = state.install_lock.try_lock().map_err(|_| {
        AppError::Failed("Cannot uninstall Studio while another installation is running.".into())
    })?;

    let paths = Paths::resolve(&app)?;
    let install_dir = version_install_dir(&paths, &version_guid);
    let download_dir = version_download_dir(&paths, &version_guid);

    if install_dir.exists() {
        tokio_fs::remove_dir_all(&install_dir)
            .await
            .with_context(|| format!("failed to remove {}", install_dir.display()))?;
    }

    if download_dir.exists() {
        let _ = tokio_fs::remove_dir_all(&download_dir).await;
    }

    let mut preferences = load_studio_preferences(&paths)?;
    if preferences
        .default_version_guid
        .as_deref()
        .map(|default_version_guid| api::same_version_guid(default_version_guid, &version_guid))
        .unwrap_or(false)
    {
        preferences.default_version_guid = None;
        save_studio_preferences(&paths, &preferences).await?;
    }

    Ok(())
}

async fn list_studio_versions_inner(app: &AppHandle) -> Result<StudioVersionsResponse> {
    let paths = Paths::resolve(app)?;
    let mut versions = discover_installed_versions(&paths)?;
    let preferences = load_studio_preferences(&paths).unwrap_or_default();
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
    let paths = Paths::resolve(app)?;
    let install_dir = version_install_dir(&paths, version_guid);
    let download_dir = version_download_dir(&paths, version_guid);
    let manifest = active_deployment()
        .install(
            &EventSink { app },
            install_dir,
            download_dir,
            version_guid,
            version,
            channel,
            published_at,
        )
        .await?;
    let install_dir = version_install_dir(&paths, &manifest.version_guid);
    let executable_path = version_executable_path(&install_dir);

    apply_saved_preferences_to_install_dir(&paths, &install_dir).await?;

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