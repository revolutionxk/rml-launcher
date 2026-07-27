use thiserror::Error;

const MH_MAGIC_64: u32 = 0xFEED_FACF;
const LC_LOAD_DYLIB: u32 = 0x0C;
const LC_SEGMENT_64: u32 = 0x19;

const HEADER_SIZE: usize = 32;
const SEGMENT_COMMAND_64_SIZE: usize = 72;
const SECTION_64_SIZE: usize = 80;
const DYLIB_COMMAND_SIZE: usize = 24;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum MachoError {
    #[error("not a thin 64-bit Mach-O image")]
    NotThin64,
    #[error("the load commands are malformed")]
    MalformedLoadCommands,
    #[error("{path} is already loaded by this image")]
    AlreadyPresent { path: String },
    #[error("no room to insert a load command: need {needed} bytes but only {available} are free")]
    InsufficientHeaderPad { needed: usize, available: usize },
}

pub fn insert_load_dylib(binary: &[u8], dylib_path: &str) -> Result<Vec<u8>, MachoError> {
    if binary.len() < HEADER_SIZE || read_u32(binary, 0) != MH_MAGIC_64 {
        return Err(MachoError::NotThin64);
    }

    let ncmds = read_u32(binary, 16);
    let sizeofcmds = read_u32(binary, 20) as usize;
    let commands_start = HEADER_SIZE;
    let commands_end = commands_start + sizeofcmds;

    if commands_end > binary.len() {
        return Err(MachoError::MalformedLoadCommands);
    }

    if loaded_dylibs(binary)?.iter().any(|loaded| loaded == dylib_path) {
        return Err(MachoError::AlreadyPresent {
            path: dylib_path.to_string(),
        });
    }

    let pad_ceiling = header_pad_ceiling(binary, ncmds, commands_start)?;

    let command = build_load_dylib_command(dylib_path);
    let available = pad_ceiling.saturating_sub(commands_end);
    if command.len() > available {
        return Err(MachoError::InsufficientHeaderPad {
            needed: command.len(),
            available,
        });
    }

    let mut patched = binary.to_vec();
    patched[commands_end..commands_end + command.len()].copy_from_slice(&command);
    write_u32(&mut patched, 16, ncmds + 1);
    write_u32(&mut patched, 20, (sizeofcmds + command.len()) as u32);

    Ok(patched)
}

pub fn loaded_dylibs(binary: &[u8]) -> Result<Vec<String>, MachoError> {
    const LC_LOAD_WEAK_DYLIB: u32 = 0x8000_0018;
    const LC_REEXPORT_DYLIB: u32 = 0x8000_001F;

    if binary.len() < HEADER_SIZE || read_u32(binary, 0) != MH_MAGIC_64 {
        return Err(MachoError::NotThin64);
    }

    let ncmds = read_u32(binary, 16);
    let mut cursor = HEADER_SIZE;
    let mut dylibs = Vec::new();

    for _ in 0..ncmds {
        if cursor + 8 > binary.len() {
            return Err(MachoError::MalformedLoadCommands);
        }

        let cmd = read_u32(binary, cursor);
        let cmdsize = read_u32(binary, cursor + 4) as usize;

        if cmdsize < 8 || cursor + cmdsize > binary.len() {
            return Err(MachoError::MalformedLoadCommands);
        }

        if matches!(cmd, LC_LOAD_DYLIB | LC_LOAD_WEAK_DYLIB | LC_REEXPORT_DYLIB) {
            let name_offset = read_u32(binary, cursor + 8) as usize;
            if name_offset < DYLIB_COMMAND_SIZE || name_offset > cmdsize {
                return Err(MachoError::MalformedLoadCommands);
            }

            let name_bytes = &binary[cursor + name_offset..cursor + cmdsize];
            let end = name_bytes.iter().position(|&byte| byte == 0).unwrap_or(name_bytes.len());
            dylibs.push(String::from_utf8_lossy(&name_bytes[..end]).into_owned());
        }

        cursor += cmdsize;
    }

    Ok(dylibs)
}

fn header_pad_ceiling(binary: &[u8], ncmds: u32, commands_start: usize) -> Result<usize, MachoError> {
    let mut cursor = commands_start;
    let mut ceiling = usize::MAX;

    for _ in 0..ncmds {
        if cursor + 8 > binary.len() {
            return Err(MachoError::MalformedLoadCommands);
        }

        let cmd = read_u32(binary, cursor);
        let cmdsize = read_u32(binary, cursor + 4) as usize;

        if cmdsize < 8 || cursor + cmdsize > binary.len() {
            return Err(MachoError::MalformedLoadCommands);
        }

        if cmd == LC_SEGMENT_64 {
            let nsects = read_u32(binary, cursor + 64);
            let mut section = cursor + SEGMENT_COMMAND_64_SIZE;

            for _ in 0..nsects {
                if section + SECTION_64_SIZE > cursor + cmdsize {
                    return Err(MachoError::MalformedLoadCommands);
                }

                let offset = read_u32(binary, section + 48) as usize;
                if offset != 0 {
                    ceiling = ceiling.min(offset);
                }

                section += SECTION_64_SIZE;
            }
        }

        cursor += cmdsize;
    }

    if ceiling == usize::MAX {
        ceiling = binary.len();
    }

    Ok(ceiling)
}

fn build_load_dylib_command(dylib_path: &str) -> Vec<u8> {
    let cmdsize = (DYLIB_COMMAND_SIZE + dylib_path.len() + 1).next_multiple_of(8);

    let mut command = Vec::with_capacity(cmdsize);
    put_u32(&mut command, LC_LOAD_DYLIB);
    put_u32(&mut command, cmdsize as u32);
    put_u32(&mut command, DYLIB_COMMAND_SIZE as u32);
    put_u32(&mut command, 2);
    put_u32(&mut command, 0x0001_0000);
    put_u32(&mut command, 0x0001_0000);
    command.extend_from_slice(dylib_path.as_bytes());
    command.resize(cmdsize, 0);

    command
}

fn read_u32(buffer: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(buffer[offset..offset + 4].try_into().unwrap())
}

fn write_u32(buffer: &mut [u8], offset: usize, value: u32) {
    buffer[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}

fn put_u32(buffer: &mut Vec<u8>, value: u32) {
    buffer.extend_from_slice(&value.to_le_bytes());
}

#[cfg(test)]
mod tests {
    use super::*;

    fn put_u32(buffer: &mut Vec<u8>, value: u32) {
        buffer.extend_from_slice(&value.to_le_bytes());
    }

    fn put_u64(buffer: &mut Vec<u8>, value: u64) {
        buffer.extend_from_slice(&value.to_le_bytes());
    }

    fn put_name16(buffer: &mut Vec<u8>, name: &str) {
        let mut field = [0_u8; 16];
        let bytes = name.as_bytes();
        field[..bytes.len()].copy_from_slice(bytes);
        buffer.extend_from_slice(&field);
    }

    fn make_macho(text_offset: u64) -> Vec<u8> {
        const NCMDS: u32 = 1;
        const SIZEOFCMDS: u32 = (SEGMENT_COMMAND_64_SIZE + SECTION_64_SIZE) as u32;

        let mut buffer = Vec::new();
        put_u32(&mut buffer, MH_MAGIC_64);
        put_u32(&mut buffer, 0x0100_000C);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 2);
        put_u32(&mut buffer, NCMDS);
        put_u32(&mut buffer, SIZEOFCMDS);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);

        put_u32(&mut buffer, LC_SEGMENT_64);
        put_u32(&mut buffer, SIZEOFCMDS);
        put_name16(&mut buffer, "__TEXT");
        put_u64(&mut buffer, 0x1_0000_0000);
        put_u64(&mut buffer, 0x4000);
        put_u64(&mut buffer, 0);
        put_u64(&mut buffer, 0x4000);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 1);
        put_u32(&mut buffer, 0);

        put_name16(&mut buffer, "__text");
        put_name16(&mut buffer, "__TEXT");
        put_u64(&mut buffer, 0x1_0000_0000 + text_offset);
        put_u64(&mut buffer, 0x100);
        put_u32(&mut buffer, text_offset as u32);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);
        put_u32(&mut buffer, 0);

        buffer.resize(text_offset as usize + 0x100, 0);
        buffer
    }

    fn read_u32(buffer: &[u8], offset: usize) -> u32 {
        u32::from_le_bytes(buffer[offset..offset + 4].try_into().unwrap())
    }

    #[test]
    fn rejects_a_dylib_that_is_already_loaded() {
        let binary = make_macho(0x1000);
        let once = insert_load_dylib(&binary, "@rpath/roblox_modloader.dylib").unwrap();

        let twice = insert_load_dylib(&once, "@rpath/roblox_modloader.dylib");

        assert_eq!(
            twice,
            Err(MachoError::AlreadyPresent {
                path: "@rpath/roblox_modloader.dylib".to_string()
            })
        );
    }

    #[test]
    fn reports_no_room_when_the_header_pad_is_full() {
        let text_offset = (HEADER_SIZE + SEGMENT_COMMAND_64_SIZE + SECTION_64_SIZE) as u64;
        let binary = make_macho(text_offset);

        let result = insert_load_dylib(&binary, "@rpath/roblox_modloader.dylib");

        assert!(matches!(result, Err(MachoError::InsufficientHeaderPad { .. })));
    }

    #[test]
    fn lists_the_loaded_dylibs() {
        let binary = make_macho(0x1000);
        let patched = insert_load_dylib(&binary, "@rpath/roblox_modloader.dylib").unwrap();

        assert_eq!(loaded_dylibs(&patched).unwrap(), vec!["@rpath/roblox_modloader.dylib".to_string()]);
    }

    #[test]
    fn appends_a_load_dylib_command() {
        let binary = make_macho(0x1000);

        let patched = insert_load_dylib(&binary, "@rpath/roblox_modloader.dylib").expect("insertion should succeed");

        assert_eq!(read_u32(&patched, 16), read_u32(&binary, 16) + 1);
        assert_eq!(patched.len(), binary.len());

        let new_command = HEADER_SIZE + read_u32(&binary, 20) as usize;
        assert_eq!(read_u32(&patched, new_command), LC_LOAD_DYLIB);

        let name_offset = read_u32(&patched, new_command + 8) as usize;
        let path_start = new_command + name_offset;
        let path_bytes = &patched[path_start..];
        let nul = path_bytes.iter().position(|&b| b == 0).unwrap();
        assert_eq!(&path_bytes[..nul], b"@rpath/roblox_modloader.dylib");
    }
}
