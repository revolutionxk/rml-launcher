#include "api/boundary.hpp"
#include "hash/algorithm.hpp"
#include "platform/path.hpp"
#include "rml/rml.h"

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <expected>
#include <filesystem>
#include <span>
#include <string>
#include <string_view>
#include <thread>
#include <utility>

namespace rml::api
{
	static_assert(hash::to_algorithm(RML_HASH_MD5) == hash::Algorithm::Md5);
	static_assert(hash::to_algorithm(RML_HASH_SHA256) == hash::Algorithm::Sha256);

	[[nodiscard]] static std::unexpected<Failure> unknown_algorithm(const std::int32_t algorithm)
	{
		return invalid_argument("Unknown hash algorithm " + std::to_string(algorithm));
	}

	static void write_terminated(const std::string_view text, char* out) noexcept
	{
		text.copy(out, text.size());
		out[text.size()] = '\0';
	}

	[[nodiscard]] static Outcome copy_to(const std::string_view text, char* out, const std::uint64_t capacity)
	{
		const auto needed = text.size() + 1;
		if (out == nullptr || capacity < needed)
			return invalid_argument("Output buffer needs " + std::to_string(needed) + " bytes");
		write_terminated(text, out);
		return {};
	}

	[[nodiscard]] static char* owned_copy(const std::string_view text) noexcept
	{
		auto* const copy = static_cast<char*>(std::malloc(text.size() + 1));
		if (copy != nullptr)
			write_terminated(text, copy);
		return copy;
	}

	static void deliver_file_hash(const hash::Algorithm algorithm, const std::filesystem::path& path, const rml_text_callback callback) noexcept
	{
		std::string hex;
		const auto status = guarded([&]() -> Outcome {
			auto result = hash::hash_file(algorithm, path);
			if (!result)
				return io_error(std::move(result.error()));
			hex = std::move(*result);
			return {};
		});
		callback(status, owned_copy(status == RML_OK ? std::string_view(hex) : last_error()));
	}
}

extern "C"
{
	std::int32_t rml_hash_bytes(const std::int32_t algorithm, const std::uint8_t* data, const std::uint64_t length, char* out_hex, const std::uint64_t out_capacity)
	{
		return rml::api::guarded([&]() -> rml::api::Outcome {
			const auto parsed = rml::hash::to_algorithm(algorithm);
			if (!parsed)
				return rml::api::unknown_algorithm(algorithm);
			if (data == nullptr && length > 0)
				return rml::api::invalid_argument("Data is null");
			const auto bytes = std::as_bytes(std::span(data, static_cast<std::size_t>(length)));
			return rml::api::copy_to(rml::hash::hash_bytes(*parsed, bytes), out_hex, out_capacity);
		});
	}

	std::int32_t rml_hash_file(const std::int32_t algorithm, const char* path, char* out_hex, const std::uint64_t out_capacity)
	{
		return rml::api::guarded([&]() -> rml::api::Outcome {
			const auto parsed = rml::hash::to_algorithm(algorithm);
			if (!parsed)
				return rml::api::unknown_algorithm(algorithm);
			if (path == nullptr)
				return rml::api::invalid_argument("Path is null");
			const auto hex = rml::hash::hash_file(*parsed, rml::platform::path_from_utf8(path));
			if (!hex)
				return rml::api::io_error(hex.error());
			return rml::api::copy_to(*hex, out_hex, out_capacity);
		});
	}

	std::int32_t rml_hash_file_async(const std::int32_t algorithm, const char* path, const rml_text_callback callback)
	{
		return rml::api::guarded([&]() -> rml::api::Outcome {
			const auto parsed = rml::hash::to_algorithm(algorithm);
			if (!parsed)
				return rml::api::unknown_algorithm(algorithm);
			if (path == nullptr || callback == nullptr)
				return rml::api::invalid_argument("Path and callback are required");
			std::thread(rml::api::deliver_file_hash, *parsed, rml::platform::path_from_utf8(path), callback).detach();
			return {};
		});
	}
}
