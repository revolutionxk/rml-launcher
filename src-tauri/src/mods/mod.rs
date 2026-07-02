mod model;

use std::{
    fs,
    path::{Path, PathBuf},
};

use anyhow::{bail, Context, Result};
use tauri::AppHandle;
use tracing::info;

use crate::studio::installed_studio_target;

pub use self::model::{ModEntry, ModsResponse};

const MODLOADER_DIR: &str = "RobloxModLoader";
const MODS_DIR: &str = "mods";
const DISABLED_DIR: &str = "disabled-mods";

fn modloader_dir(install_dir: &Path) -> PathBuf {
    install_dir.join(MODLOADER_DIR)
}

fn mods_dir(install_dir: &Path) -> PathBuf {
    modloader_dir(install_dir).join(MODS_DIR)
}

fn disabled_dir(install_dir: &Path) -> PathBuf {
    modloader_dir(install_dir).join(DISABLED_DIR)
}

#[tauri::command]
pub async fn list_mods(app: AppHandle, version_guid: String) -> Result<ModsResponse, String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;

    tokio::task::spawn_blocking(move || list_mods_blocking(&install_dir))
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
}

pub(crate) fn count_mods(install_dir: &Path) -> (usize, usize) {
    let enabled = count_dir_children(&mods_dir(install_dir));
    let disabled = count_dir_children(&disabled_dir(install_dir));

    (enabled, enabled + disabled)
}

pub(crate) fn loader_installed(install_dir: &Path) -> bool {
    modloader_dir(install_dir).is_dir() || install_dir.join("rml-modloader.json").is_file()
}

#[tauri::command]
pub async fn set_mod_enabled(
    app: AppHandle,
    version_guid: String,
    mod_id: String,
    enabled: bool,
) -> Result<(), String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;
    let mod_id = sanitize_mod_id(&mod_id).map_err(|error| error.to_string())?;

    tokio::task::spawn_blocking(move || set_mod_enabled_blocking(&install_dir, &mod_id, enabled))
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn remove_mod(app: AppHandle, version_guid: String, mod_id: String) -> Result<(), String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;
    let mod_id = sanitize_mod_id(&mod_id).map_err(|error| error.to_string())?;

    tokio::task::spawn_blocking(move || remove_mod_blocking(&install_dir, &mod_id))
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn import_mod(
    app: AppHandle,
    version_guid: String,
    source_path: String,
) -> Result<ModEntry, String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;

    tokio::task::spawn_blocking(move || import_mod_blocking(&install_dir, Path::new(&source_path)))
        .await
        .map_err(|error| error.to_string())?
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn open_mods_dir(app: AppHandle, version_guid: String) -> Result<(), String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;
    let dir = mods_dir(&install_dir);

    if !loader_installed(&install_dir) {
        return Err("Install the mod loader for this version first.".to_string());
    }

    fs::create_dir_all(&dir)
        .with_context(|| format!("failed to create {}", dir.display()))
        .map_err(|error| error.to_string())?;

    crate::platform::reveal_path(&dir).map_err(|error| error.to_string())
}

fn list_mods_blocking(install_dir: &Path) -> Result<ModsResponse> {
    let loader_installed = loader_installed(install_dir);
    let mut mods = Vec::new();

    collect_mods(&mods_dir(install_dir), true, &mut mods)?;
    collect_mods(&disabled_dir(install_dir), false, &mut mods)?;

    mods.sort_by(|left, right| left.name.to_lowercase().cmp(&right.name.to_lowercase()));

    Ok(ModsResponse {
        loader_installed,
        mods,
    })
}

fn collect_mods(dir: &Path, enabled: bool, mods: &mut Vec<ModEntry>) -> Result<()> {
    if !dir.is_dir() {
        return Ok(());
    }

    for entry in fs::read_dir(dir).with_context(|| format!("failed to read {}", dir.display()))? {
        let entry = entry?;

        if !entry.file_type()?.is_dir() {
            continue;
        }

        let path = entry.path();
        let id = entry.file_name().to_string_lossy().into_owned();
        let (size_bytes, kinds) = inspect_mod(&path);

        mods.push(ModEntry {
            id: id.clone(),
            name: id,
            enabled,
            size_bytes,
            kinds,
        });
    }

    Ok(())
}

fn inspect_mod(mod_dir: &Path) -> (u64, Vec<String>) {
    let mut kinds = Vec::new();

    for (folder, kind) in [("native", "native"), ("dotnet", "dotnet"), ("scripts", "scripts")] {
        if mod_dir.join(folder).is_dir() {
            kinds.push(kind.to_string());
        }
    }

    if kinds.is_empty() {
        kinds.push("other".to_string());
    }

    (dir_size(mod_dir), kinds)
}

fn dir_size(dir: &Path) -> u64 {
    let Ok(entries) = fs::read_dir(dir) else {
        return 0;
    };

    let mut total = 0;

    for entry in entries.flatten() {
        let Ok(file_type) = entry.file_type() else {
            continue;
        };

        if file_type.is_dir() {
            total += dir_size(&entry.path());
        } else if let Ok(metadata) = entry.metadata() {
            total += metadata.len();
        }
    }

    total
}

fn count_dir_children(dir: &Path) -> usize {
    let Ok(entries) = fs::read_dir(dir) else {
        return 0;
    };

    entries
        .flatten()
        .filter(|entry| entry.file_type().map(|file_type| file_type.is_dir()).unwrap_or(false))
        .count()
}

fn set_mod_enabled_blocking(install_dir: &Path, mod_id: &str, enabled: bool) -> Result<()> {
    let (from, to) = if enabled {
        (disabled_dir(install_dir).join(mod_id), mods_dir(install_dir).join(mod_id))
    } else {
        (mods_dir(install_dir).join(mod_id), disabled_dir(install_dir).join(mod_id))
    };

    if !from.is_dir() {
        if to.is_dir() {
            return Ok(());
        }

        bail!("the mod '{mod_id}' was not found");
    }

    if let Some(parent) = to.parent() {
        fs::create_dir_all(parent).with_context(|| format!("failed to create {}", parent.display()))?;
    }

    fs::rename(&from, &to)
        .with_context(|| format!("failed to move {} to {}", from.display(), to.display()))?;

    info!(mod_id, enabled, "toggled mod");

    Ok(())
}

fn remove_mod_blocking(install_dir: &Path, mod_id: &str) -> Result<()> {
    let candidates = [mods_dir(install_dir).join(mod_id), disabled_dir(install_dir).join(mod_id)];
    let mut removed = false;

    for candidate in candidates {
        if candidate.is_dir() {
            fs::remove_dir_all(&candidate)
                .with_context(|| format!("failed to remove {}", candidate.display()))?;
            removed = true;
        }
    }

    if !removed {
        bail!("the mod '{mod_id}' was not found");
    }

    info!(mod_id, "removed mod");

    Ok(())
}

fn import_mod_blocking(install_dir: &Path, source: &Path) -> Result<ModEntry> {
    if !loader_installed(install_dir) {
        bail!("Install the mod loader for this version first.");
    }

    let mods_dir = mods_dir(install_dir);
    fs::create_dir_all(&mods_dir).with_context(|| format!("failed to create {}", mods_dir.display()))?;

    let is_zip = source
        .extension()
        .map(|extension| extension.eq_ignore_ascii_case("zip"))
        .unwrap_or(false);

    let mod_name = if is_zip {
        import_zip(source, &mods_dir)?
    } else if source.is_dir() {
        import_dir(source, &mods_dir)?
    } else {
        bail!("select a mod folder or a .zip archive");
    };

    let mod_dir = mods_dir.join(&mod_name);
    let (size_bytes, kinds) = inspect_mod(&mod_dir);

    info!(mod_name, "imported mod");

    Ok(ModEntry {
        id: mod_name.clone(),
        name: mod_name,
        enabled: true,
        size_bytes,
        kinds,
    })
}

fn import_dir(source: &Path, mods_dir: &Path) -> Result<String> {
    let name = source
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .context("the selected folder has no name")?;
    let destination = mods_dir.join(&name);

    if destination.exists() {
        bail!("a mod named '{name}' already exists");
    }

    copy_dir_recursive(source, &destination)?;

    Ok(name)
}

fn import_zip(source: &Path, mods_dir: &Path) -> Result<String> {
    let file = fs::File::open(source).with_context(|| format!("failed to open {}", source.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", source.display()))?;

    let root = single_archive_root(&mut archive);
    let mod_name = root.clone().unwrap_or_else(|| {
        source
            .file_stem()
            .map(|stem| stem.to_string_lossy().into_owned())
            .unwrap_or_else(|| "mod".to_string())
    });

    let destination = mods_dir.join(&mod_name);
    if destination.exists() {
        bail!("a mod named '{mod_name}' already exists");
    }

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .with_context(|| format!("failed to read archive entry {index} from {}", source.display()))?;

        let Some(enclosed) = entry.enclosed_name().map(PathBuf::from) else {
            continue;
        };

        let relative = match root.as_deref() {
            Some(root) => match enclosed.strip_prefix(root) {
                Ok(relative) => relative.to_path_buf(),
                Err(_) => continue,
            },
            None => enclosed,
        };

        if relative.as_os_str().is_empty() {
            continue;
        }

        let out_path = destination.join(&relative);

        if entry.is_dir() {
            fs::create_dir_all(&out_path).with_context(|| format!("failed to create {}", out_path.display()))?;
            continue;
        }

        if let Some(parent) = out_path.parent() {
            fs::create_dir_all(parent).with_context(|| format!("failed to create {}", parent.display()))?;
        }

        let mut output = fs::File::create(&out_path)
            .with_context(|| format!("failed to create {}", out_path.display()))?;
        std::io::copy(&mut entry, &mut output)
            .with_context(|| format!("failed to extract {}", out_path.display()))?;
    }

    Ok(mod_name)
}

fn single_archive_root(archive: &mut zip::ZipArchive<fs::File>) -> Option<String> {
    let mut root: Option<String> = None;

    for index in 0..archive.len() {
        let entry = archive.by_index(index).ok()?;
        let enclosed = entry.enclosed_name()?;
        let mut components = enclosed.components();
        let first = components.next()?.as_os_str().to_string_lossy().into_owned();

        if components.next().is_none() && !entry.is_dir() {
            return None;
        }

        match &root {
            Some(existing) if existing != &first => return None,
            _ => root = Some(first),
        }
    }

    root
}

fn copy_dir_recursive(source: &Path, destination: &Path) -> Result<()> {
    fs::create_dir_all(destination)
        .with_context(|| format!("failed to create {}", destination.display()))?;

    for entry in fs::read_dir(source).with_context(|| format!("failed to read {}", source.display()))? {
        let entry = entry?;
        let path = entry.path();
        let target = destination.join(entry.file_name());

        if entry.file_type()?.is_dir() {
            copy_dir_recursive(&path, &target)?;
        } else {
            fs::copy(&path, &target)
                .with_context(|| format!("failed to copy {} to {}", path.display(), target.display()))?;
        }
    }

    Ok(())
}

fn sanitize_mod_id(mod_id: &str) -> Result<String> {
    let trimmed = mod_id.trim();

    if trimmed.is_empty()
        || trimmed == "."
        || trimmed == ".."
        || trimmed.contains('/')
        || trimmed.contains('\\')
    {
        bail!("invalid mod id");
    }

    Ok(trimmed.to_string())
}
