#include "platform/path.hpp"

namespace rml::platform
{
	std::filesystem::path path_from_utf8(const std::string_view text)
	{
		return std::u8string(text.begin(), text.end());
	}

	std::string to_utf8(const std::filesystem::path& path)
	{
		const auto text = path.u8string();
		return {text.begin(), text.end()};
	}
}
