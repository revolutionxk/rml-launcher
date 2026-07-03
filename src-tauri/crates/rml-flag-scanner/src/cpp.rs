use std::{
    collections::{BTreeMap, BTreeSet},
    path::Path,
};

use goblin::pe::PE;

use crate::{
    pattern::{KNOWN_FLAG_TYPES, MIN_REGISTRATION_ROUTINES, REGISTRATION_PATTERN},
    pe::{
        collect_sections, read_ascii_cstring, resolve_relative_target, section_name, FileSection,
        PatternScanner,
    },
    read_file, ScanError,
};

const MAX_ROUTINE_GAP: usize = 1000;

struct RawFlag {
    name: String,
    byte_param: u8,
    routine: usize,
}

pub(crate) fn dump_cpp_flags(executable: &Path) -> Result<Vec<String>, ScanError> {
    let binary = read_file(executable)?;
    let pe = PE::parse(&binary).map_err(|error| ScanError::Pe(error.to_string()))?;
    let sections = collect_sections(&pe);

    let text = pe
        .sections
        .iter()
        .find(|section| section_name(section) == ".text")
        .ok_or(ScanError::MissingSection(".text"))?;
    let text_start = text.pointer_to_raw_data as usize;
    let text_size = text.size_of_raw_data as usize;

    let raw_flags = collect_raw_flags(&binary, &sections, text_start, text_size)?;
    let routines = raw_flags
        .iter()
        .map(|flag| flag.routine)
        .collect::<BTreeSet<_>>();

    if routines.len() < MIN_REGISTRATION_ROUTINES {
        return Err(ScanError::NotEnoughRoutines {
            found: routines.len(),
            expected: MIN_REGISTRATION_ROUTINES,
        });
    }

    let type_table: BTreeMap<usize, &str> = routines
        .into_iter()
        .take(KNOWN_FLAG_TYPES.len())
        .zip(KNOWN_FLAG_TYPES.iter().copied())
        .collect();

    Ok(assemble_names(raw_flags, &type_table))
}

fn collect_raw_flags(
    binary: &[u8],
    sections: &[FileSection],
    text_start: usize,
    text_size: usize,
) -> Result<Vec<RawFlag>, ScanError> {
    let mut scanner = PatternScanner::new(binary, REGISTRATION_PATTERN, text_start, text_size)?;
    let mut raw_flags = Vec::new();
    let mut last_routine: Option<usize> = None;

    while let Some(pos) = scanner.find_next() {
        let Some(name_offset) = resolve_relative_target(binary, sections, pos + 13, 7, pos + 16)
        else {
            continue;
        };
        let Some(routine) = resolve_relative_target(binary, sections, pos + 20, 5, pos + 21) else {
            continue;
        };

        if let Some(previous) = last_routine {
            if previous.abs_diff(routine) > MAX_ROUTINE_GAP {
                continue;
            }
        }

        let Some(name) = read_ascii_cstring(binary, name_offset) else {
            continue;
        };

        raw_flags.push(RawFlag {
            name,
            byte_param: binary[pos + 2],
            routine,
        });
        last_routine = Some(routine);
    }

    Ok(raw_flags)
}

fn assemble_names(raw_flags: Vec<RawFlag>, type_table: &BTreeMap<usize, &str>) -> Vec<String> {
    let mut seen: BTreeMap<String, usize> = BTreeMap::new();
    let mut names = Vec::new();

    for raw in raw_flags {
        let Some(data_type) = type_table.get(&raw.routine) else {
            continue;
        };

        let mut name = String::new();
        if raw.byte_param == 2 {
            name.push('D');
        }
        name.push_str(data_type);
        name.push_str(&raw.name);

        let count = seen.entry(name.clone()).or_insert(0);
        if *count > 0 {
            name.push_str(&(*count + 1).to_string());
        }
        *count += 1;

        names.push(name);
    }

    names.sort();
    names.dedup();
    names
}

#[cfg(test)]
mod tests {
    use super::*;

    fn raw(name: &str, byte_param: u8, routine: usize) -> RawFlag {
        RawFlag {
            name: name.to_string(),
            byte_param,
            routine,
        }
    }

    fn type_table() -> BTreeMap<usize, &'static str> {
        BTreeMap::from([(10usize, "FFlag"), (20usize, "FInt")])
    }

    #[test]
    fn prefixes_type_and_marks_dynamic_flags() {
        let names = assemble_names(vec![raw("Foo", 1, 10), raw("Bar", 2, 20)], &type_table());
        assert!(names.contains(&"FFlagFoo".to_string()));
        assert!(names.contains(&"DFIntBar".to_string()));
    }

    #[test]
    fn suffixes_repeated_names_with_a_version() {
        let names = assemble_names(vec![raw("Foo", 1, 10), raw("Foo", 1, 10)], &type_table());
        assert_eq!(names, vec!["FFlagFoo".to_string(), "FFlagFoo2".to_string()]);
    }

    #[test]
    fn skips_flags_whose_routine_is_unknown() {
        let names = assemble_names(vec![raw("Foo", 1, 999)], &type_table());
        assert!(names.is_empty());
    }
}
