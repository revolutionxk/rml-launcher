#include "zip/entry_path.hpp"

#include <algorithm>
#include <ranges>

namespace rml::zip
{
	[[nodiscard]] static constexpr bool is_ascii_letter(const char character) noexcept
	{
		return (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z');
	}

	std::optional<std::string> safe_entry_path(const std::string_view name)
	{
		if (name.contains('\0'))
			return std::nullopt;
		std::string normal(name);
		std::ranges::replace(normal, '\\', '/');
		if (normal.starts_with('/') || (normal.size() >= 2 && is_ascii_letter(normal[0]) && normal[1] == ':'))
			return std::nullopt;
		std::string safe;
		for (const auto part : std::views::split(normal, '/'))
		{
			const std::string_view segment(part.begin(), part.end());
			if (segment.empty() || segment == ".")
				continue;
			if (segment == ".." || segment.contains(':'))
				return std::nullopt;
			if (!safe.empty())
				safe += '/';
			safe += segment;
		}
		return safe;
	}
}
