#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace rml::zip
{
	[[nodiscard]] std::optional<std::string> safe_entry_path(std::string_view name);
}
