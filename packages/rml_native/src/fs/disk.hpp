#pragma once

#include "error.hpp"

#include <cstdint>
#include <expected>
#include <filesystem>

namespace rml::fs
{
	[[nodiscard]] std::expected<std::uint64_t, Error> free_space(const std::filesystem::path& path);
}
