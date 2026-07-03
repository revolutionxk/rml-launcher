mod cpp;
mod lua;
mod pattern;
mod pe;

use std::{collections::BTreeMap, path::Path};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FlagSource {
    Binary,
    Lua,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScannedFlag {
    pub name: String,
    pub source: FlagSource,
}

#[derive(Debug, thiserror::Error)]
pub enum ScanError {
    #[error("failed to read {path}")]
    Read {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("failed to parse the Studio executable as a PE image: {0}")]
    Pe(String),

    #[error("could not find the {0} section in the Studio executable")]
    MissingSection(&'static str),

    #[error("invalid scan pattern byte '{0}'")]
    InvalidPatternByte(String),

    #[error(
        "pattern scan found {found} flag registration routines, expected at least {expected} \
         — the signature is likely stale for this Studio build"
    )]
    NotEnoughRoutines { found: usize, expected: usize },

    #[error("failed to compile a Lua flag pattern")]
    Regex(#[from] regex::Error),
}

pub fn scan_flags(executable: &Path, extra_content: &Path) -> Result<Vec<ScannedFlag>, ScanError> {
    let mut flags: BTreeMap<String, FlagSource> = BTreeMap::new();

    for name in cpp::dump_cpp_flags(executable)? {
        flags.insert(name, FlagSource::Binary);
    }

    for name in lua::dump_lua_flags(extra_content)? {
        flags.entry(name).or_insert(FlagSource::Lua);
    }

    Ok(flags
        .into_iter()
        .map(|(name, source)| ScannedFlag { name, source })
        .collect())
}

pub(crate) fn read_file(path: &Path) -> Result<Vec<u8>, ScanError> {
    std::fs::read(path).map_err(|source| read_error(path, source))
}

pub(crate) fn read_error(path: &Path, source: std::io::Error) -> ScanError {
    ScanError::Read {
        path: path.display().to_string(),
        source,
    }
}
