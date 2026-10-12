#pragma once

#include "error.hpp"

#include <expected>
#include <filesystem>
#include <string>

namespace rml::exe
{
	struct BundleInfo
	{
		std::string identifier;
		std::string version;
		std::string executable;
	};

	[[nodiscard]] std::expected<BundleInfo, Error> bundle_info(const std::filesystem::path& bundle);
}
