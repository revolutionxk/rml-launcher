#include "rml/rml.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <filesystem>
#include <span>
#include <string>
#include <thread>

#include "error.h"
#include "hash/hash_file.h"

namespace {

char* duplicate(const std::string& text) {
  auto* copy = static_cast<char*>(std::malloc(text.size() + 1));
  if (copy != nullptr) {
    std::memcpy(copy, text.c_str(), text.size() + 1);
  }
  return copy;
}

int32_t fail(rml_status status, const std::string& message) {
  rml::set_last_error(message);
  return status;
}

int32_t write_hex(const std::string& hex, char* out, uint64_t capacity) {
  if (out == nullptr || capacity < hex.size() + 1) {
    return fail(RML_ERR_INVALID_ARGUMENT,
                "Output buffer needs " + std::to_string(hex.size() + 1) + " bytes");
  }
  std::memcpy(out, hex.c_str(), hex.size() + 1);
  return RML_OK;
}

bool parse(int32_t algorithm, rml::hash::Algorithm& out) {
  if (rml::hash::parse_algorithm(algorithm, out)) {
    return true;
  }
  rml::set_last_error("Unknown hash algorithm " + std::to_string(algorithm));
  return false;
}

}

extern "C" {

const char* rml_version(void) { return RML_NATIVE_VERSION; }

const char* rml_last_error(void) { return rml::last_error(); }

void rml_free(void* pointer) { std::free(pointer); }

int32_t rml_hash_bytes(int32_t algorithm, const uint8_t* data, uint64_t length,
                       char* out_hex, uint64_t out_capacity) {
  try {
    rml::hash::Algorithm parsed{};
    if (!parse(algorithm, parsed)) {
      return RML_ERR_INVALID_ARGUMENT;
    }
    if (data == nullptr && length > 0) {
      return fail(RML_ERR_INVALID_ARGUMENT, "Data is null");
    }
    const std::span<const std::uint8_t> bytes(data, static_cast<std::size_t>(length));
    return write_hex(rml::hash::hash_bytes(parsed, bytes), out_hex, out_capacity);
  } catch (const std::exception& error) {
    return fail(RML_ERR_INTERNAL, error.what());
  } catch (...) {
    return fail(RML_ERR_INTERNAL, "Unknown error");
  }
}

int32_t rml_hash_file(int32_t algorithm, const char* path, char* out_hex,
                      uint64_t out_capacity) {
  try {
    rml::hash::Algorithm parsed{};
    if (!parse(algorithm, parsed)) {
      return RML_ERR_INVALID_ARGUMENT;
    }
    if (path == nullptr) {
      return fail(RML_ERR_INVALID_ARGUMENT, "Path is null");
    }
    const rml::hash::Outcome outcome =
        rml::hash::hash_file(parsed, rml::hash::path_from_utf8(path));
    if (!outcome.ok) {
      return fail(RML_ERR_IO, outcome.text);
    }
    return write_hex(outcome.text, out_hex, out_capacity);
  } catch (const std::exception& error) {
    return fail(RML_ERR_INTERNAL, error.what());
  } catch (...) {
    return fail(RML_ERR_INTERNAL, "Unknown error");
  }
}

int32_t rml_hash_file_async(int32_t algorithm, const char* path,
                            rml_text_callback callback) {
  try {
    rml::hash::Algorithm parsed{};
    if (!parse(algorithm, parsed)) {
      return RML_ERR_INVALID_ARGUMENT;
    }
    if (path == nullptr || callback == nullptr) {
      return fail(RML_ERR_INVALID_ARGUMENT, "Path and callback are required");
    }
    std::filesystem::path target = rml::hash::path_from_utf8(path);
    std::thread([parsed, target = std::move(target), callback]() {
      try {
        const rml::hash::Outcome outcome = rml::hash::hash_file(parsed, target);
        callback(outcome.ok ? RML_OK : RML_ERR_IO, duplicate(outcome.text));
      } catch (const std::exception& error) {
        callback(RML_ERR_INTERNAL, duplicate(error.what()));
      } catch (...) {
        callback(RML_ERR_INTERNAL, duplicate("Unknown error"));
      }
    }).detach();
    return RML_OK;
  } catch (const std::exception& error) {
    return fail(RML_ERR_INTERNAL, error.what());
  } catch (...) {
    return fail(RML_ERR_INTERNAL, "Unknown error");
  }
}

}
