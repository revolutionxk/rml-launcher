#pragma once

#include <string>
#include <string_view>

namespace rml::platform
{
	[[nodiscard]] std::string utf16_to_utf8(std::u16string_view text);
}
