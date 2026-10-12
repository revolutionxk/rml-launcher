#include "api/boundary.hpp"
#include "api/json.hpp"
#include "exe/bundle_info.hpp"
#include "exe/pe_version.hpp"
#include "platform/path.hpp"
#include "rml/rml.h"

#include <cstdint>
#include <expected>
#include <filesystem>
#include <string>
#include <system_error>
#include <utility>

namespace rml::api
{
	[[nodiscard]] static std::expected<std::string, Error> describe(const std::filesystem::path& path)
	{
		std::error_code ec;
		if (std::filesystem::is_directory(path, ec))
		{
			const auto info = exe::bundle_info(path);
			if (!info)
				return std::unexpected(info.error());
			return "{\"identifier\":" + json::quote(info->identifier) + ",\"version\":" + json::quote(info->version)
			    + ",\"executable\":" + json::quote(info->executable) + "}";
		}
		const auto version = exe::file_version(path);
		if (!version)
			return std::unexpected(version.error());
		return "{\"version\":" + json::quote(*version) + "}";
	}

	extern "C"
	{
		RML_API std::int32_t rml_executable_info(const char* path, char** out_json)
		{
			return guarded([&]() -> Outcome {
				if (path == nullptr || *path == '\0' || out_json == nullptr)
					return invalid_argument("Path and output are required");
				auto text = describe(platform::path_from_utf8(path));
				if (!text)
					return io_error(std::move(text.error()));
				return deliver_text(*text, out_json);
			});
		}
	}
}
