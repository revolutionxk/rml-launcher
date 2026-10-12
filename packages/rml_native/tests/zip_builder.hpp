#pragma once

#include "bytes.hpp"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace rml::testing
{
	struct ZipEntry
	{
		std::string name;
		std::string data;
		std::uint32_t mode = 0100644;
		bool corrupt_crc = false;
	};

	[[nodiscard]] inline std::uint32_t crc32(const std::string_view data)
	{
		std::uint32_t crc = 0xFFFFFFFF;
		for (const auto character : data)
		{
			crc ^= static_cast<unsigned char>(character);
			for (int bit = 0; bit < 8; ++bit)
				crc = (crc >> 1) ^ (0xEDB88320 & (0u - (crc & 1u)));
		}
		return ~crc;
	}

	[[nodiscard]] inline Bytes stored_zip(const std::vector<ZipEntry>& entries)
	{
		Bytes local;
		Bytes central;
		for (const auto& entry : entries)
		{
			const auto crc = crc32(entry.data) ^ (entry.corrupt_crc ? 1u : 0u);
			const auto offset = static_cast<std::uint32_t>(local.size());
			const auto size = static_cast<std::uint32_t>(entry.data.size());
			const auto name_size = static_cast<std::uint16_t>(entry.name.size());

			append_u32(local, 0x04034B50);
			append_u16(local, 20);
			append_u16(local, 0x0800);
			append_u16(local, 0);
			append_u16(local, 0);
			append_u16(local, 0x21);
			append_u32(local, crc);
			append_u32(local, size);
			append_u32(local, size);
			append_u16(local, name_size);
			append_u16(local, 0);
			append_text(local, entry.name);
			append_text(local, entry.data);

			append_u32(central, 0x02014B50);
			append_u16(central, 0x0314);
			append_u16(central, 20);
			append_u16(central, 0x0800);
			append_u16(central, 0);
			append_u16(central, 0);
			append_u16(central, 0x21);
			append_u32(central, crc);
			append_u32(central, size);
			append_u32(central, size);
			append_u16(central, name_size);
			append_u16(central, 0);
			append_u16(central, 0);
			append_u16(central, 0);
			append_u16(central, 0);
			append_u32(central, entry.mode << 16);
			append_u32(central, offset);
			append_text(central, entry.name);
		}
		Bytes zip = local;
		zip.insert(zip.end(), central.begin(), central.end());
		append_u32(zip, 0x06054B50);
		append_u16(zip, 0);
		append_u16(zip, 0);
		append_u16(zip, static_cast<std::uint16_t>(entries.size()));
		append_u16(zip, static_cast<std::uint16_t>(entries.size()));
		append_u32(zip, static_cast<std::uint32_t>(central.size()));
		append_u32(zip, static_cast<std::uint32_t>(local.size()));
		append_u16(zip, 0);
		return zip;
	}
}
