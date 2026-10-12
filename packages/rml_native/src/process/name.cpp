#include "process/process.hpp"

#include <algorithm>
#include <cctype>

namespace rml::process
{
	bool same_name(const std::string_view left, const std::string_view right) noexcept
	{
		return std::ranges::equal(left, right, [](const char a, const char b) {
			return std::tolower(static_cast<unsigned char>(a)) == std::tolower(static_cast<unsigned char>(b));
		});
	}

	std::string_view file_name(const std::string_view path) noexcept
	{
		const auto slash = path.find_last_of("/\\");
		return slash == std::string_view::npos ? path : path.substr(slash + 1);
	}
}
