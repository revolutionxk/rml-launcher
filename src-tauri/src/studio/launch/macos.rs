use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{bail, Context, Result};

use super::StudioLauncher;
use crate::studio::paths::version_bundle_path;

pub struct MacosLauncher;

impl StudioLauncher for MacosLauncher {
    fn launch(&self, install_dir: &Path, uri: Option<&str>) -> Result<()> {
        let bundle = locate_bundle(install_dir)?;

        let mut command = Command::new("open");
        command.arg("-a").arg(&bundle);
        if let Some(uri) = uri {
            command.arg(uri);
        }

        let status = command
            .status()
            .with_context(|| format!("failed to run open for {}", bundle.display()))?;

        if !status.success() {
            bail!("open exited with a failure launching {}", bundle.display());
        }

        Ok(())
    }
}

fn locate_bundle(install_dir: &Path) -> Result<PathBuf> {
    let preferred = version_bundle_path(install_dir);
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
        (None, _) => bail!("Studio was not found in {}", install_dir.display()),
    }
}
