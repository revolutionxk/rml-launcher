use goblin::pe::{section_table::SectionTable, PE};

use crate::ScanError;

#[derive(Debug, Clone, Copy)]
pub(crate) struct FileSection {
    virtual_address: usize,
    virtual_size: usize,
    raw_offset: usize,
    raw_size: usize,
}

pub(crate) struct PatternScanner<'a> {
    binary: &'a [u8],
    pattern: Vec<Option<u8>>,
    pos: usize,
    end: usize,
}

impl<'a> PatternScanner<'a> {
    pub(crate) fn new(
        binary: &'a [u8],
        pattern: &str,
        start: usize,
        length: usize,
    ) -> Result<Self, ScanError> {
        let pattern = pattern
            .split_ascii_whitespace()
            .map(|token| match token {
                "??" | "?" => Ok(None),
                _ => u8::from_str_radix(token, 16)
                    .map(Some)
                    .map_err(|_| ScanError::InvalidPatternByte(token.to_string())),
            })
            .collect::<Result<Vec<_>, _>>()?;

        Ok(Self {
            binary,
            pattern,
            pos: start,
            end: start.saturating_add(length).min(binary.len()),
        })
    }

    pub(crate) fn find_next(&mut self) -> Option<usize> {
        while self.pos + self.pattern.len() <= self.end {
            let matched = self.pattern.iter().enumerate().all(|(index, expected)| {
                expected.is_none_or(|byte| self.binary[self.pos + index] == byte)
            });

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

pub(crate) fn collect_sections(pe: &PE<'_>) -> Vec<FileSection> {
    pe.sections
        .iter()
        .map(|section| FileSection {
            virtual_address: section.virtual_address as usize,
            virtual_size: usize::max(
                section.virtual_size as usize,
                section.size_of_raw_data as usize,
            ),
            raw_offset: section.pointer_to_raw_data as usize,
            raw_size: section.size_of_raw_data as usize,
        })
        .collect()
}

pub(crate) fn section_name(section: &SectionTable) -> String {
    section
        .name()
        .map(|name| name.trim_end_matches('\0').to_string())
        .unwrap_or_default()
}

pub(crate) fn read_ascii_cstring(binary: &[u8], offset: usize) -> Option<String> {
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

    String::from_utf8(buffer)
        .ok()
        .filter(|value| !value.trim().is_empty())
}

pub(crate) fn resolve_relative_target(
    binary: &[u8],
    sections: &[FileSection],
    instruction_offset: usize,
    instruction_len: usize,
    displacement_offset: usize,
) -> Option<usize> {
    let instruction_rva = file_offset_to_rva(instruction_offset, sections)?;
    let next_rva = instruction_rva + instruction_len;
    let displacement = read_i32(binary, displacement_offset)? as isize;
    let target_rva = (next_rva as isize + displacement) as usize;

    rva_to_file_offset(target_rva, sections)
}

fn file_offset_to_rva(offset: usize, sections: &[FileSection]) -> Option<usize> {
    sections
        .iter()
        .find(|section| {
            offset >= section.raw_offset && offset < section.raw_offset + section.raw_size
        })
        .map(|section| offset - section.raw_offset + section.virtual_address)
}

fn rva_to_file_offset(rva: usize, sections: &[FileSection]) -> Option<usize> {
    sections
        .iter()
        .find(|section| {
            rva >= section.virtual_address && rva < section.virtual_address + section.virtual_size
        })
        .map(|section| rva - section.virtual_address + section.raw_offset)
}

fn read_i32(binary: &[u8], offset: usize) -> Option<i32> {
    let bytes = binary.get(offset..offset + 4)?;
    Some(i32::from_le_bytes(
        bytes.try_into().expect("slice length is always 4"),
    ))
}

#[cfg(test)]
mod tests {
    use super::PatternScanner;

    #[test]
    fn pattern_scanner_supports_wildcards() {
        let binary = [0x10, 0x41, 0xB8, 0x01, 0x00, 0x00, 0x00, 0x90];
        let mut scanner =
            PatternScanner::new(&binary, "41 B8 ?? 00 00 00", 0, binary.len()).unwrap();

        assert_eq!(scanner.find_next(), Some(1));
        assert_eq!(scanner.find_next(), None);
    }
}
