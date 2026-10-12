#pragma once

#include <concepts>
#include <cstddef>
#include <span>
#include <string>
#include <string_view>

namespace rml::hash
{
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
}
