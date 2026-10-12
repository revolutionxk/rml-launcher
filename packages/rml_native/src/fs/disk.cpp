#include "fs/disk.hpp"

#include "platform/path.hpp"

#include <system_error>

namespace rml::fs
{
	std::expected<std::uint64_t, Error> free_space(const std::filesystem::path& path)
	{
		std::error_code ec;
		auto existing = path;
		while (!std::filesystem::exists(existing, ec) && existing.has_relative_path())
			existing = existing.parent_path();
		const auto info = std::filesystem::space(existing, ec);
		if (ec)
			return fail("Can't read free space for " + platform::to_utf8(path) + ": " + ec.message());
		return info.available;
	}
}
