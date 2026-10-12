#pragma once

#include <string>
#include <string_view>

namespace rml::api::json
{
	[[nodiscard]] std::string quote(std::string_view text);
}
