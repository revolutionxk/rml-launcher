#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <span>
#include <string>

namespace rml::hash {

enum class Algorithm : std::int32_t { md5 = 0, sha256 = 1 };

struct Outcome {
  bool ok;
  std::string text;
};

bool parse_algorithm(std::int32_t raw, Algorithm& out);

std::string hash_bytes(Algorithm algorithm, std::span<const std::uint8_t> data);

Outcome hash_file(Algorithm algorithm, const std::filesystem::path& path);

std::filesystem::path path_from_utf8(const char* text);

std::string path_to_utf8(const std::filesystem::path& path);

}
