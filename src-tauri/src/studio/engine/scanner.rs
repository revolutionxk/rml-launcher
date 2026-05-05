use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::Path,
};

use anyhow::{bail, Context, Result};
use goblin::pe::{section_table::SectionTable, PE};
use regex::Regex;

use super::{model::{EngineFlagSource, ScannedFlag}, paths::extra_content_dir};

const BASE_PATTERN: &str = "41 B8 ?? 00 00 00 48 8D 15 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? E9";

#[derive(Debug, Clone, Copy)]
struct FileSection {
    virtual_address: usize,
    virtual_size: usize,
    raw_offset: usize,
    raw_size: usize,
}

#[derive(Debug)]
struct RawFlagEntry {
    name: String,
    byte_param: u8,
    target_offset: usize,
}

#[derive(Debug)]
struct PatternScanner<'a> {
    binary: &'a [u8],
    pattern: Vec<Option<u8>>,
    pos: usize,
    end: usize,
}

impl<'a> PatternScanner<'a> {
    fn new(binary: &'a [u8], pattern: &str, start: usize, length: usize) -> Result<Self> {
        let pattern = pattern
            .split_ascii_whitespace()
            .map(|token| {
                if token == "??" || token == "?" {
                    Ok(None)
                } else {
                    u8::from_str_radix(token, 16)
                        .map(Some)
                        .with_context(|| format!("invalid pattern byte {token}"))
                }
            })
            .collect::<Result<Vec<_>>>()?;

        Ok(Self {
            binary,
            pattern,
            pos: start,
            end: start.saturating_add(length).min(binary.len()),
        })
    }

    fn find_next(&mut self) -> Option<usize> {
        while self.pos + self.pattern.len() <= self.end {
            let matched = self
                .pattern
                .iter()
                .enumerate()
                .all(|(index, expected)| expected.is_none_or(|byte| self.binary[self.pos + index] == byte));

            if matched {
                let result = self.pos;
                self.pos += self.pattern.len();
                return Some(result);
            }

            self.pos += 1;
        }

        None
    }
}

pub fn scan_install_flags(install_dir: &Path, executable_path: &Path) -> Result<Vec<ScannedFlag>> {
    let mut flags = BTreeMap::new();

    for name in dump_cpp_flags(executable_path)? {
        flags.insert(name, EngineFlagSource::Binary);
    }

    for name in dump_lua_flags(&extra_content_dir(install_dir))? {
        flags.entry(name).or_insert(EngineFlagSource::Lua);
    }

    Ok(flags
        .into_iter()
        .map(|(name, source)| ScannedFlag { name, source })
        .collect())
}

fn dump_cpp_flags(executable_path: &Path) -> Result<Vec<String>> {
    let binary = fs::read(executable_path)
        .with_context(|| format!("failed to read {}", executable_path.display()))?;
    let pe = PE::parse(&binary).context("failed to parse RobloxStudioBeta.exe as a PE image")?;
    let sections = collect_sections(&pe);
    let text_section = pe
        .sections
        .iter()
        .find(|section| section_name(section) == ".text")
        .context("failed to locate the .text section in RobloxStudioBeta.exe")?;
    let text_start = text_section.pointer_to_raw_data as usize;
    let text_size = text_section.size_of_raw_data as usize;
    let mut scanner = PatternScanner::new(&binary, BASE_PATTERN, text_start, text_size)?;
    let mut raw_flags = Vec::new();
    let mut data_type_targets = BTreeSet::new();
    let mut last_target_offset: Option<usize> = None;

    while let Some(pos) = scanner.find_next() {
        if pos + 25 > binary.len() {
            continue;
        }

        let name_offset = match resolve_relative_target(&binary, &sections, pos + 13, 7, pos + 16) {
            Ok(offset) => offset,
            Err(_) => continue,
        };
        let target_offset = match resolve_relative_target(&binary, &sections, pos + 20, 5, pos + 21) {
            Ok(offset) => offset,
            Err(_) => continue,
        };

        if let Some(previous) = last_target_offset {
            if previous.abs_diff(target_offset) > 1000 {
                continue;
            }
        }

        let Some(name) = read_ascii_cstring(&binary, name_offset) else {
            continue;
        };

        raw_flags.push(RawFlagEntry {
            name,
            byte_param: binary[pos + 2],
            target_offset,
        });
        data_type_targets.insert(target_offset);
        last_target_offset = Some(target_offset);
    }

    if data_type_targets.len() < 5 {
        bail!(
            "pattern scan discovered {} registration routines, expected at least 5",
            data_type_targets.len(),
        );
    }

    let known_types = ["FFlag", "SFFlag", "FInt", "FLog", "FString"];
    let type_table = data_type_targets
        .iter()
        .take(known_types.len())
        .copied()
        .zip(known_types)
        .collect::<BTreeMap<_, _>>();
    let mut duplicate_versions = BTreeMap::<String, usize>::new();
    let mut final_flags = Vec::new();

    for raw in raw_flags {
        let Some(data_type) = type_table.get(&raw.target_offset) else {
            continue;
        };

        let mut name = String::new();
        if raw.byte_param == 2 {
            name.push('D');
        }

        name.push_str(data_type);
        name.push_str(&raw.name);

        let duplicate_count = duplicate_versions.entry(name.clone()).or_insert(0);
        if *duplicate_count > 0 {
            name.push_str(&(*duplicate_count + 1).to_string());
        }
        *duplicate_count += 1;
        final_flags.push(name);
    }

    final_flags.sort();
    final_flags.dedup();

    Ok(final_flags)
}

fn dump_lua_flags(extra_content_path: &Path) -> Result<Vec<String>> {
    if !extra_content_path.exists() {
        return Ok(Vec::new());
    }

    let fast_flags = Regex::new(r#"game:(?:Get|Define)Fast(Flag|Int|String)\(\"(\w+)\"\)"#)
        .context("failed to compile the fast flag Lua regex")?;
    let user_flags = Regex::new(r#"(?:IsUserFeatureEnabled|getUserFlag)\(\"(\w+)\"\)"#)
        .context("failed to compile the user flag Lua regex")?;
    let mut results = BTreeSet::new();
    let mut stack = vec![extra_content_path.to_path_buf()];

    while let Some(dir) = stack.pop() {
        for entry in fs::read_dir(&dir).with_context(|| format!("failed to enumerate {}", dir.display()))? {
            let entry = entry?;
            let file_type = entry.file_type()?;
            let path = entry.path();

            if file_type.is_dir() {
                stack.push(path);
                continue;
            }

            if path.extension().and_then(|extension| extension.to_str()) != Some("lua") {
                continue;
            }

            let contents = fs::read_to_string(&path)
                .with_context(|| format!("failed to read {}", path.display()))?;

            for captures in fast_flags.captures_iter(&contents) {
                let flag = format!("F{}{}", &captures[1], &captures[2]);
                results.insert(flag);
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

fn collect_sections(pe: &PE<'_>) -> Vec<FileSection> {
    pe.sections
        .iter()
        .map(|section| FileSection {
            virtual_address: section.virtual_address as usize,
            virtual_size: usize::max(section.virtual_size as usize, section.size_of_raw_data as usize),
            raw_offset: section.pointer_to_raw_data as usize,
            raw_size: section.size_of_raw_data as usize,
        })
        .collect()
}

fn section_name(section: &SectionTable) -> String {
    section
        .name()
        .map(|name| name.trim_end_matches('\0').to_string())
        .unwrap_or_default()
}

fn read_ascii_cstring(binary: &[u8], offset: usize) -> Option<String> {
    if offset >= binary.len() {
        return None;
    }

    let mut buffer = Vec::new();

    for byte in binary.iter().copied().skip(offset).take(256) {
        if byte == 0 {
            break;
        }

        if !(30..=127).contains(&byte) {
            return None;
        }

        buffer.push(byte);
    }

    if buffer.is_empty() {
        return None;
    }

    String::from_utf8(buffer).ok().filter(|value| !value.trim().is_empty())
}

fn resolve_relative_target(
    binary: &[u8],
    sections: &[FileSection],
    instruction_offset: usize,
    instruction_len: usize,
    displacement_offset: usize,
) -> Result<usize> {
    let instruction_rva = file_offset_to_rva(instruction_offset, sections)?;
    let next_rva = instruction_rva + instruction_len;
    let displacement = read_i32(binary, displacement_offset)? as isize;
    let target_rva = (next_rva as isize + displacement) as usize;

    rva_to_file_offset(target_rva, sections)
}

fn file_offset_to_rva(offset: usize, sections: &[FileSection]) -> Result<usize> {
    let section = sections
        .iter()
        .find(|section| offset >= section.raw_offset && offset < section.raw_offset + section.raw_size)
        .context("failed to map the file offset back to an RVA")?;

    Ok(offset - section.raw_offset + section.virtual_address)
}

fn rva_to_file_offset(rva: usize, sections: &[FileSection]) -> Result<usize> {
    let section = sections
        .iter()
        .find(|section| rva >= section.virtual_address && rva < section.virtual_address + section.virtual_size)
        .context("failed to map the RVA into a file offset")?;

    Ok(rva - section.virtual_address + section.raw_offset)
}

fn read_i32(binary: &[u8], offset: usize) -> Result<i32> {
    let bytes = binary
        .get(offset..offset + 4)
        .context("relative displacement was out of bounds")?;

    Ok(i32::from_le_bytes(bytes.try_into().expect("slice length is always 4")))
}

#[cfg(test)]
mod tests {
    use super::PatternScanner;

    #[test]
    fn pattern_scanner_supports_wildcards() {
        let binary = [0x10, 0x41, 0xB8, 0x01, 0x00, 0x00, 0x00, 0x90];
        let mut scanner = PatternScanner::new(&binary, "41 B8 ?? 00 00 00", 0, binary.len()).unwrap();

        assert_eq!(scanner.find_next(), Some(1));
        assert_eq!(scanner.find_next(), None);
    }
}