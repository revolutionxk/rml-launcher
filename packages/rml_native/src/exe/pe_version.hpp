#pragma once

#include "error.hpp"

#include <expected>
#include <filesystem>
#include <string>

namespace rml::exe
{
	[[nodiscard]] std::expected<std::string, Error> file_version(const std::filesystem::path& path);
}
