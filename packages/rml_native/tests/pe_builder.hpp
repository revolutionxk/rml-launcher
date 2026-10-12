#pragma once

#include "bytes.hpp"

#include <cstdint>
#include <string_view>
#include <vector>

namespace rml::testing
{
	[[nodiscard]] inline Bytes utf16(const std::u16string_view text)
	{
		Bytes bytes;
		for (const auto unit : text)
			append_u16(bytes, unit);
		append_u16(bytes, 0);
		return bytes;
	}

	[[nodiscard]] inline Bytes version_block(const std::u16string_view key, const std::uint16_t type, const Bytes& value, const std::uint16_t value_length, const std::vector<Bytes>& children = {})
	{
		Bytes block(6);
		const auto name = utf16(key);
		block.insert(block.end(), name.begin(), name.end());
		pad4(block);
		block.insert(block.end(), value.begin(), value.end());
		for (const auto& child : children)
		{
			pad4(block);
			block.insert(block.end(), child.begin(), child.end());
		}
		put_u16(block, 0, static_cast<std::uint16_t>(block.size()));
		put_u16(block, 2, value_length);
		put_u16(block, 4, type);
		return block;
	}

	[[nodiscard]] inline Bytes string_entry(const std::u16string_view key, const std::u16string_view value)
	{
		return version_block(key, 1, utf16(value), static_cast<std::uint16_t>(value.size() + 1));
	}

	[[nodiscard]] inline Bytes fixed_info(const std::uint16_t a, const std::uint16_t b, const std::uint16_t c, const std::uint16_t d)
	{
		Bytes info(52);
		put_u32(info, 0, 0xFEEF04BD);
		put_u32(info, 4, 0x00010000);
		put_u32(info, 8, std::uint32_t{a} << 16 | b);
		put_u32(info, 12, std::uint32_t{c} << 16 | d);
		return info;
	}

	[[nodiscard]] inline Bytes version_info(const Bytes& fixed, const std::u16string_view file_version)
	{
		std::vector<Bytes> children;
		if (!file_version.empty())
		{
			const auto table = version_block(u"040904b0", 1, {}, 0, {string_entry(u"CompanyName", u"Roblox Corporation"), string_entry(u"FileVersion", file_version)});
			children.push_back(version_block(u"StringFileInfo", 1, {}, 0, {table}));
		}
		return version_block(u"VS_VERSION_INFO", 0, fixed, static_cast<std::uint16_t>(fixed.size()), children);
	}

	[[nodiscard]] inline Bytes portable_executable(const Bytes& version)
	{
		constexpr std::uint32_t section_rva = 0x1000;
		constexpr std::size_t section_offset = 0x200;
		constexpr std::size_t version_offset = 88;
		constexpr std::size_t optional_header = 0x58;
		constexpr std::size_t section_header = optional_header + 240;

		Bytes resources(version_offset);
		put_u16(resources, 14, 1);
		put_u32(resources, 16, 16);
		put_u32(resources, 20, 0x80000000 | 24);
		put_u16(resources, 38, 1);
		put_u32(resources, 40, 1);
		put_u32(resources, 44, 0x80000000 | 48);
		put_u16(resources, 62, 1);
		put_u32(resources, 64, 0x409);
		put_u32(resources, 68, 72);
		put_u32(resources, 72, section_rva + version_offset);
		put_u32(resources, 76, static_cast<std::uint32_t>(version.size()));
		resources.insert(resources.end(), version.begin(), version.end());
		const auto size = static_cast<std::uint32_t>(resources.size());

		Bytes image(section_offset);
		put_u16(image, 0, 0x5A4D);
		put_u32(image, 0x3C, 0x40);
		put_u32(image, 0x40, 0x00004550);
		put_u16(image, 0x44, 0x8664);
		put_u16(image, 0x46, 1);
		put_u16(image, 0x54, 240);
		put_u16(image, optional_header, 0x20B);
		put_u32(image, optional_header + 108, 16);
		put_u32(image, optional_header + 128, section_rva);
		put_u32(image, optional_header + 132, size);
		put_u32(image, section_header + 8, size);
		put_u32(image, section_header + 12, section_rva);
		put_u32(image, section_header + 16, size);
		put_u32(image, section_header + 20, static_cast<std::uint32_t>(section_offset));
		image.insert(image.end(), resources.begin(), resources.end());
		return image;
	}
}
