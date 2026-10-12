#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace rml::testing
{
	using Bytes = std::vector<std::byte>;

	inline void put_u16(Bytes& bytes, const std::size_t offset, const std::uint16_t value)
	{
		bytes[offset] = static_cast<std::byte>(value & 0xFF);
		bytes[offset + 1] = static_cast<std::byte>(value >> 8);
	}

	inline void put_u32(Bytes& bytes, const std::size_t offset, const std::uint32_t value)
	{
		put_u16(bytes, offset, static_cast<std::uint16_t>(value & 0xFFFF));
		put_u16(bytes, offset + 2, static_cast<std::uint16_t>(value >> 16));
	}

	inline void append_u16(Bytes& bytes, const std::uint16_t value)
	{
		bytes.push_back(static_cast<std::byte>(value & 0xFF));
		bytes.push_back(static_cast<std::byte>(value >> 8));
	}

	inline void append_u32(Bytes& bytes, const std::uint32_t value)
	{
		append_u16(bytes, static_cast<std::uint16_t>(value & 0xFFFF));
		append_u16(bytes, static_cast<std::uint16_t>(value >> 16));
	}

	inline void append_text(Bytes& bytes, const std::string_view text)
	{
		for (const auto character : text)
			bytes.push_back(static_cast<std::byte>(character));
	}

	inline void pad4(Bytes& bytes)
	{
		while (bytes.size() % 4 != 0)
			bytes.push_back(std::byte{0});
	}

	[[nodiscard]] inline std::string as_text(const Bytes& bytes)
	{
		return {reinterpret_cast<const char*>(bytes.data()), bytes.size()};
	}
}
