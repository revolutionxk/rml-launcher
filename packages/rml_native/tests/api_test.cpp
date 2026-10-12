#include <doctest/doctest.h>

#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <future>
#include <string>
#include <utility>

#include "rml/rml.h"

namespace {

std::string utf8(const std::filesystem::path& path) {
  const std::u8string text = path.u8string();
  return {text.begin(), text.end()};
}

std::filesystem::path write_file(const std::filesystem::path& path, const std::string& content) {
  std::filesystem::create_directories(path.parent_path());
  std::ofstream out(path, std::ios::binary);
  out << content;
  return path;
}

std::promise<std::pair<int32_t, std::string>>* pending = nullptr;

void on_hashed(int32_t status, char* text) {
  pending->set_value({status, text != nullptr ? std::string(text) : std::string()});
  rml_free(text);
}

}

TEST_CASE("version comes from the build") {
  CHECK(std::string(rml_version()) == "0.1.0");
}

TEST_CASE("hashing bytes writes a terminated hex string") {
  char out[65] = {};
  const auto* data = reinterpret_cast<const uint8_t*>("abc");
  REQUIRE(rml_hash_bytes(RML_HASH_SHA256, data, 3, out, sizeof(out)) == RML_OK);
  CHECK(std::string(out) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

TEST_CASE("a small output buffer is rejected with a reason") {
  char out[10] = {};
  const auto* data = reinterpret_cast<const uint8_t*>("abc");
  CHECK(rml_hash_bytes(RML_HASH_MD5, data, 3, out, sizeof(out)) == RML_ERR_INVALID_ARGUMENT);
  CHECK(std::string(rml_last_error()).find("33") != std::string::npos);
}

TEST_CASE("an unknown algorithm is rejected") {
  char out[65] = {};
  CHECK(rml_hash_bytes(7, nullptr, 0, out, sizeof(out)) == RML_ERR_INVALID_ARGUMENT);
}

TEST_CASE("a missing file is an io error") {
  char out[65] = {};
  CHECK(rml_hash_file(RML_HASH_SHA256, "/definitely/missing/rml.bin", out, sizeof(out)) == RML_ERR_IO);
}

TEST_CASE("files with non-ascii paths hash correctly") {
  const std::filesystem::path dir = std::filesystem::temp_directory_path() / std::filesystem::path(u8"rml native Ação ✓");
  const std::filesystem::path file = write_file(dir / std::filesystem::path(u8"mods ção.bin"), "abc");
  char out[33] = {};
  REQUIRE(rml_hash_file(RML_HASH_MD5, utf8(file).c_str(), out, sizeof(out)) == RML_OK);
  CHECK(std::string(out) == "900150983cd24fb0d6963f7d28e17f72");
  std::filesystem::remove_all(dir);
}

TEST_CASE("async hashing reports through the callback") {
  const std::filesystem::path dir = std::filesystem::temp_directory_path() / "rml native async";
  const std::filesystem::path file = write_file(dir / "abc.bin", "abc");
  std::promise<std::pair<int32_t, std::string>> promise;
  pending = &promise;
  auto future = promise.get_future();
  REQUIRE(rml_hash_file_async(RML_HASH_SHA256, utf8(file).c_str(), on_hashed) == RML_OK);
  REQUIRE(future.wait_for(std::chrono::seconds(10)) == std::future_status::ready);
  const auto [status, text] = future.get();
  CHECK(status == RML_OK);
  CHECK(text == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  std::filesystem::remove_all(dir);
}

TEST_CASE("async hashing of a missing file reports the error text") {
  std::promise<std::pair<int32_t, std::string>> promise;
  pending = &promise;
  auto future = promise.get_future();
  REQUIRE(rml_hash_file_async(RML_HASH_MD5, "/definitely/missing/rml.bin", on_hashed) == RML_OK);
  REQUIRE(future.wait_for(std::chrono::seconds(10)) == std::future_status::ready);
  const auto [status, text] = future.get();
  CHECK(status == RML_ERR_IO);
  CHECK(text.find("missing") != std::string::npos);
}

TEST_CASE("the os reduce motion setting is reported or unknown") {
  const int32_t reduce = rml_os_reduce_motion();
  CHECK((reduce == -1 || reduce == 0 || reduce == 1));
}
