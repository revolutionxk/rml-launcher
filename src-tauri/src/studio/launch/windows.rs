use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};

use super::StudioLauncher;
use crate::studio::paths::{version_executable_path, version_launcher_path};

pub struct WindowsLauncher;

impl StudioLauncher for WindowsLauncher {
    fn launch(&self, install_dir: &Path, uri: Option<&str>) -> Result<()> {
        let launcher = version_launcher_path(install_dir);
        let executable = version_executable_path(install_dir);
        let program = if uri.is_some() && launcher.exists() {
            launcher
        } else {
            executable
        };

        if !program.exists() {
            bail!("Studio was not found in {}", install_dir.display());
        }

        let mut command = Command::new(&program);
        command.current_dir(install_dir);
        if let Some(uri) = uri {
            command.arg(uri);
        }
        command
            .spawn()
            .with_context(|| format!("failed to launch {}", program.display()))?;

        Ok(())
    }
}
