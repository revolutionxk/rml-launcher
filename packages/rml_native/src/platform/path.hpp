#pragma once

#include <filesystem>
#include <string>
#include <string_view>

namespace rml::platform
{
	[[nodiscard]] std::filesystem::path path_from_utf8(std::string_view text);
	[[nodiscard]] std::string to_utf8(const std::filesystem::path& path);
}
