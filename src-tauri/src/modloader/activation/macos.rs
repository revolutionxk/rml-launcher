use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use tracing::info;

use super::{codesign, macho, ActivationContext, LoaderActivation};

const LOADER_LIBRARY: &str = "roblox_modloader.dylib";
const BACKUP_SUFFIX: &str = ".rml-backup";

pub struct MacosActivation;

impl LoaderActivation for MacosActivation {
    fn activate(&self, context: &ActivationContext<'_>) -> Result<()> {
        info!(installation_id = context.installation_id, "activating the mod loader for Studio version");
        let bundle = locate_bundle(context.install_dir)?;
        let binary = main_binary(&bundle)?;
        let loader = loader_library_path(context.install_dir)?;

        if is_loaded(&binary, &loader)? {
            info!(bundle = %bundle.display(), "mod loader already inserted into Studio; nothing to do");
            return Ok(());
        }

        back_up_once(&binary)?;

        let original = fs::read(&binary).with_context(|| format!("failed to read {}", binary.display()))?;
        let loader_name = loader.to_str().context("the mod loader path is not valid UTF-8")?;
        let patched = macho::insert_load_dylib(&original, loader_name).with_context(|| format!("failed to insert the load command into {}", binary.display()))?;

        fs::write(&binary, &patched).with_context(|| format!("failed to write {}", binary.display()))?;

        codesign::resign_bundle(&bundle, &binary, true)?;

        info!(bundle = %bundle.display(), loader = %loader.display(), "mod loader inserted and Studio re-signed");
        Ok(())
    }

    fn deactivate(&self, context: &ActivationContext<'_>) -> Result<()> {
        let Ok(bundle) = locate_bundle(context.install_dir) else {
            return Ok(());
        };
        let binary = main_binary(&bundle)?;
        let backup = backup_path(&binary);

        if !backup.exists() {
            return Ok(());
        }

        fs::rename(&backup, &binary).with_context(|| format!("failed to restore {} from {}", binary.display(), backup.display()))?;

        codesign::resign_bundle(&bundle, &binary, false)?;

        info!(bundle = %bundle.display(), "mod loader removed from Studio and bundle re-signed");
        Ok(())
    }
}

fn locate_bundle(install_dir: &Path) -> Result<PathBuf> {
    let preferred = install_dir.join("RobloxStudio.app");
    if preferred.is_dir() {
        return Ok(preferred);
    }

    let mut bundles = fs::read_dir(install_dir)
        .with_context(|| format!("failed to read {}", install_dir.display()))?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.is_dir() && path.extension().is_some_and(|extension| extension == "app"));

    match (bundles.next(), bundles.next()) {
        (Some(bundle), None) => Ok(bundle),
        (Some(_), Some(_)) => bail!("{} contains more than one .app bundle", install_dir.display()),
        (None, _) => bail!("no Studio .app bundle found in {}", install_dir.display()),
    }
}

fn main_binary(bundle: &Path) -> Result<PathBuf> {
    let info_plist = bundle.join("Contents/Info.plist");
    let info = plist::Value::from_file(&info_plist)
        .with_context(|| format!("failed to read {}", info_plist.display()))?;

    let executable = info
        .as_dictionary()
        .and_then(|dictionary| dictionary.get("CFBundleExecutable"))
        .and_then(plist::Value::as_string)
        .context("the bundle's Info.plist has no CFBundleExecutable")?;

    Ok(bundle.join("Contents/MacOS").join(executable))
}

fn loader_library_path(install_dir: &Path) -> Result<PathBuf> {
    let path = install_dir.join(LOADER_LIBRARY);

    fs::canonicalize(&path).with_context(|| format!("the mod loader library is missing: {}", path.display()))
}

fn is_loaded(binary: &Path, loader: &Path) -> Result<bool> {
    let bytes = fs::read(binary).with_context(|| format!("failed to read {}", binary.display()))?;
    let loader_name = loader.to_str().context("the mod loader path is not valid UTF-8")?;

    Ok(macho::loaded_dylibs(&bytes)
        .with_context(|| format!("failed to read the load commands of {}", binary.display()))?
        .iter()
        .any(|loaded| loaded == loader_name))
}

fn back_up_once(binary: &Path) -> Result<()> {
    let backup = backup_path(binary);

    if backup.exists() {
        return Ok(());
    }

    fs::copy(binary, &backup).with_context(|| format!("failed to back up {} to {}", binary.display(), backup.display()))?;
    Ok(())
}

fn backup_path(binary: &Path) -> PathBuf {
    let mut name = binary.as_os_str().to_os_string();
    name.push(BACKUP_SUFFIX);
    PathBuf::from(name)
}
