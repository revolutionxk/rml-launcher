use std::path::Path;

use anyhow::{bail, Result};

use super::StudioLauncher;

pub struct LinuxLauncher;

impl StudioLauncher for LinuxLauncher {
    fn launch(&self, _install_dir: &Path, _uri: Option<&str>) -> Result<()> {
        bail!("Launching Studio directly is not available on Linux. Run Studio through Vinegar instead.")
    }
}
