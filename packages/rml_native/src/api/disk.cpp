#include "fs/disk.hpp"

#include "api/boundary.hpp"
#include "platform/path.hpp"
#include "rml/rml.h"

#include <cstdint>
#include <utility>

namespace rml::api
{
	extern "C"
	{
		RML_API std::int32_t rml_disk_free(const char* path, std::uint64_t* out_bytes)
		{
			return guarded([&]() -> Outcome {
				if (path == nullptr || *path == '\0' || out_bytes == nullptr)
					return invalid_argument("Path and output are required");
				auto bytes = fs::free_space(platform::path_from_utf8(path));
				if (!bytes)
					return io_error(std::move(bytes.error()));
				*out_bytes = *bytes;
				return {};
			});
		}
	}
}
