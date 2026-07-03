use std::{collections::BTreeSet, path::Path};

use regex::Regex;

use crate::{read_error, ScanError};

pub(crate) fn dump_lua_flags(extra_content: &Path) -> Result<Vec<String>, ScanError> {
    if !extra_content.exists() {
        return Ok(Vec::new());
    }

    let fast_flags = Regex::new(r#"game:(?:Get|Define)Fast(Flag|Int|String)\(\"(\w+)\"\)"#)?;
    let user_flags = Regex::new(r#"(?:IsUserFeatureEnabled|getUserFlag)\(\"(\w+)\"\)"#)?;

    let mut results = BTreeSet::new();
    let mut pending = vec![extra_content.to_path_buf()];

    while let Some(dir) = pending.pop() {
        for entry in std::fs::read_dir(&dir).map_err(|source| read_error(&dir, source))? {
            let entry = entry.map_err(|source| read_error(&dir, source))?;
            let path = entry.path();
            let file_type = entry.file_type().map_err(|source| read_error(&path, source))?;

            if file_type.is_dir() {
                pending.push(path);
                continue;
            }

            if path.extension().and_then(|ext| ext.to_str()) != Some("lua") {
                continue;
            }

            let contents =
                std::fs::read_to_string(&path).map_err(|source| read_error(&path, source))?;

            for captures in fast_flags.captures_iter(&contents) {
                results.insert(format!("F{}{}", &captures[1], &captures[2]));
            }

            for captures in user_flags.captures_iter(&contents) {
                let flag = format!("FFlag{}", &captures[1]);
                if flag != "FFlagUserDoStuff" {
                    results.insert(flag);
                }
            }
        }
    }

    Ok(results.into_iter().collect())
}
