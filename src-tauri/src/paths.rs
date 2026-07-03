use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use tauri::{AppHandle, Manager};

#[derive(Debug, Clone)]
pub struct Paths {
    data_dir: PathBuf,
}

impl Paths {
    pub fn resolve(app: &AppHandle) -> Result<Self> {
        let data_dir = app
            .path()
            .app_data_dir()
            .context("failed to resolve the app data directory")?;

        Ok(Self { data_dir })
    }
    
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }
}
