#pragma once

#include "error.hpp"
#include "platform/path.hpp"

#include <concepts>
#include <cstddef>
#include <expected>
#include <filesystem>
#include <fstream>
#include <span>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

namespace rml::hash
{
	inline constexpr std::size_t file_chunk_size = 1 << 20;

	template<typename H>
	concept Hasher = std::default_initializable<H> && requires(H hasher, std::span<const std::byte> data) {
		hasher.update(data);
		{ hasher.finish() } -> std::convertible_to<std::span<const std::byte>>;
	};

	[[nodiscard]] constexpr std::string to_hex(const std::span<const std::byte> bytes)
	{
		constexpr std::string_view digits = "0123456789abcdef";
		std::string hex;
		hex.reserve(bytes.size() * 2);
		for (const auto byte : bytes)
		{
			hex += digits[std::to_integer<std::size_t>(byte >> 4)];
			hex += digits[std::to_integer<std::size_t>(byte & std::byte{0x0f})];
		}
		return hex;
	}

	template<Hasher H>
	[[nodiscard]] std::string hash_bytes(const std::span<const std::byte> data)
	{
		H hasher;
		hasher.update(data);
		return to_hex(hasher.finish());
	}

	template<Hasher H>
	[[nodiscard]] std::expected<std::string, Error> hash_file(const std::filesystem::path& path)
	{
		std::error_code ec;
		if (!std::filesystem::is_regular_file(path, ec))
			return fail("Not a file: " + platform::to_utf8(path));

		std::ifstream file(path, std::ios::binary);
		if (!file)
			return fail("Can't open " + platform::to_utf8(path));

		H hasher;
		std::vector<char> chunk(file_chunk_size);
		while (file)
		{
			file.read(chunk.data(), std::ssize(chunk));
			hasher.update(std::as_bytes(std::span(chunk).first(static_cast<std::size_t>(file.gcount()))));
		}

		if (file.bad())
			return fail("Can't read " + platform::to_utf8(path));

		return to_hex(hasher.finish());
	}
}
