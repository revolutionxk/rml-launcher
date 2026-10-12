#pragma once

#include "error.hpp"

#include <cstdint>
#include <expected>
#include <filesystem>
#include <functional>
#include <string>
#include <vector>

namespace rml::zip
{
	struct ExtractedFile
	{
		std::string path;
		std::uint64_t size;
	};

	struct Extraction
	{
		std::uint64_t bytes = 0;
		std::vector<ExtractedFile> files;
	};

	using Progress = std::function<void(std::uint64_t done, std::uint64_t total)>;

	[[nodiscard]] std::expected<Extraction, Error> extract(const std::filesystem::path& archive, const std::filesystem::path& destination, const Progress& progress);
}
