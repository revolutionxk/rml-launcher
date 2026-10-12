#pragma once

#include "error.hpp"

#include <cstddef>
#include <cstdint>
#include <expected>
#include <filesystem>
#include <optional>
#include <span>
#include <string>

namespace rml::hash
{
	enum class Algorithm : std::int32_t
	{
		Md5 = 0,
		Sha256 = 1,
	};

	[[nodiscard]] constexpr std::optional<Algorithm> to_algorithm(const std::int32_t raw) noexcept
	{
		switch (const auto algorithm = static_cast<Algorithm>(raw))
		{
		case Algorithm::Md5:
		case Algorithm::Sha256: return algorithm;
		}
		return std::nullopt;
	}

	[[nodiscard]] std::string hash_bytes(Algorithm algorithm, std::span<const std::byte> data);
	[[nodiscard]] std::expected<std::string, Error> hash_file(Algorithm algorithm, const std::filesystem::path& path);
}
