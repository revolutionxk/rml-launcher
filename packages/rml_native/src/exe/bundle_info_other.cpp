#include "exe/bundle_info.hpp"

namespace rml::exe
{
	std::expected<BundleInfo, Error> bundle_info(const std::filesystem::path&)
	{
		return fail("App bundles are read on macOS only");
	}
}
