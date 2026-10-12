#include "api/boundary.hpp"
#include "api/json.hpp"
#include "platform/path.hpp"
#include "rml/rml.h"
#include "zip/extract.hpp"

#include <cstddef>
#include <cstdint>
#include <expected>
#include <filesystem>
#include <string>
#include <thread>
#include <utility>

namespace rml::api
{
	[[nodiscard]] static std::string extraction_json(const zip::Extraction& extraction)
	{
		std::string text = "{\"bytes\":" + std::to_string(extraction.bytes) + ",\"files\":[";
		for (std::size_t index = 0; index < extraction.files.size(); ++index)
		{
			const auto& file = extraction.files[index];
			if (index > 0)
				text += ',';
			text += "{\"path\":" + json::quote(file.path) + ",\"size\":" + std::to_string(file.size) + "}";
		}
		return text + "]}";
	}

	static void deliver_extraction(const std::filesystem::path& archive, const std::filesystem::path& destination, const rml_progress_callback progress, const rml_text_callback done) noexcept
	{
		const zip::Progress report = [progress](const std::uint64_t current, const std::uint64_t total) {
			if (progress != nullptr)
				progress(current, total);
		};
		const auto result = attempt([&]() -> std::expected<std::string, Failure> {
			auto extraction = zip::extract(archive, destination, report);
			if (!extraction)
				return io_error(std::move(extraction.error()));
			return extraction_json(*extraction);
		});
		done(result ? RML_OK : result.error().status, owned_copy(result ? *result : result.error().message));
	}

	extern "C"
	{
		RML_API std::int32_t rml_zip_extract_async(const char* archive, const char* destination, const rml_progress_callback progress, const rml_text_callback done)
		{
			return guarded([&]() -> Outcome {
				if (archive == nullptr || destination == nullptr || done == nullptr)
					return invalid_argument("Archive, destination and callback are required");
				std::thread(deliver_extraction, platform::path_from_utf8(archive), platform::path_from_utf8(destination), progress, done)
				    .detach();
				return {};
			});
		}
	}
}
