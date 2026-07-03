use std::path::Path;

use anyhow::{Context, Result};
use rml_flag_scanner::{FlagSource, ScannedFlag as RawScannedFlag};

use super::{
    model::{EngineFlagSource, ScannedFlag},
    paths::extra_content_dir,
};

pub fn scan_install_flags(install_dir: &Path, executable_path: &Path) -> Result<Vec<ScannedFlag>> {
    let extra_content = extra_content_dir(install_dir);

    let scanned = rml_flag_scanner::scan_flags(executable_path, &extra_content)
        .context("failed to scan the Studio installation for Fast Flags")?;

    Ok(scanned.into_iter().map(into_scanned_flag).collect())
}

fn into_scanned_flag(flag: RawScannedFlag) -> ScannedFlag {
    ScannedFlag {
        name: flag.name,
        source: match flag.source {
            FlagSource::Binary => EngineFlagSource::Binary,
            FlagSource::Lua => EngineFlagSource::Lua,
        },
    }
}
