#include "hash/hash_file.h"

#include <fstream>
#include <string_view>
#include <system_error>
#include <vector>

#include "hash/hex.h"
#include "hash/md5.h"
#include "hash/sha256.h"

namespace rml::hash {

namespace {

template <typename Hasher>
std::string digest_bytes(std::span<const std::uint8_t> data) {
  Hasher hasher;
  hasher.update(data.data(), data.size());
  const auto digest = hasher.finish();
  return to_hex(digest);
}

template <typename Hasher>
Outcome digest_file(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    return {false, "Can't open " + path_to_utf8(path)};
  }
  Hasher hasher;
  std::vector<char> buffer(1 << 20);
  while (file) {
    file.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));
    const std::streamsize got = file.gcount();
    if (got > 0) {
      hasher.update(reinterpret_cast<const std::uint8_t*>(buffer.data()),
                    static_cast<std::size_t>(got));
    }
  }
  if (file.bad()) {
    return {false, "Can't read " + path_to_utf8(path)};
  }
  const auto digest = hasher.finish();
  return {true, to_hex(digest)};
}

}

bool parse_algorithm(std::int32_t raw, Algorithm& out) {
  if (raw == static_cast<std::int32_t>(Algorithm::md5) ||
      raw == static_cast<std::int32_t>(Algorithm::sha256)) {
    out = static_cast<Algorithm>(raw);
    return true;
  }
  return false;
}

std::string hash_bytes(Algorithm algorithm, std::span<const std::uint8_t> data) {
  return algorithm == Algorithm::md5 ? digest_bytes<Md5>(data) : digest_bytes<Sha256>(data);
}

Outcome hash_file(Algorithm algorithm, const std::filesystem::path& path) {
  std::error_code error;
  if (!std::filesystem::is_regular_file(path, error)) {
    return {false, "Not a file: " + path_to_utf8(path)};
  }
  return algorithm == Algorithm::md5 ? digest_file<Md5>(path) : digest_file<Sha256>(path);
}

std::filesystem::path path_from_utf8(const char* text) {
  const std::string_view view(text);
  return std::filesystem::path(std::u8string(view.begin(), view.end()));
}

std::string path_to_utf8(const std::filesystem::path& path) {
  const std::u8string text = path.u8string();
  return {text.begin(), text.end()};
}

}
