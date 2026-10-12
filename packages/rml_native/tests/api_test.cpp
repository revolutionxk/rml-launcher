#include "platform/path.hpp"
#include "rml/rml.h"

#include <chrono>
#include <cstdint>
#include <doctest/doctest.h>
#include <filesystem>
#include <fstream>
#include <future>
#include <string>
#include <string_view>
#include <system_error>

using namespace std::chrono_literals;

namespace
{
	struct Reply
	{
		std::int32_t status;
		std::string text;
	};

	class TempDirectory
	{
	public:
		explicit TempDirectory(const std::filesystem::path& name) :
		    m_path(std::filesystem::temp_directory_path() / name)
		{
			std::filesystem::create_directories(m_path);
		}

		TempDirectory(const TempDirectory&) = delete;
		TempDirectory& operator=(const TempDirectory&) = delete;

		~TempDirectory()
		{
			std::error_code ec;
			std::filesystem::remove_all(m_path, ec);
		}

		[[nodiscard]] const std::filesystem::path& path() const noexcept
		{
			return m_path;
		}

		[[nodiscard]] std::string write(const std::filesystem::path& name, const std::string_view content) const
		{
			const auto file = m_path / name;
			std::ofstream(file, std::ios::binary) << content;
			return rml::platform::to_utf8(file);
		}

	private:
		std::filesystem::path m_path;
	};

	std::promise<Reply>* g_pending = nullptr;

	void on_hashed(const std::int32_t status, char* text)
	{
		g_pending->set_value({status, text != nullptr ? std::string(text) : std::string()});
		rml_free(text);
	}

	[[nodiscard]] Reply hash_file_async(const std::int32_t algorithm, const std::string& path)
	{
		std::promise<Reply> promise;
		g_pending = &promise;
		auto future = promise.get_future();
		REQUIRE(rml_hash_file_async(algorithm, path.c_str(), on_hashed) == RML_OK);
		REQUIRE(future.wait_for(10s) == std::future_status::ready);
		return future.get();
	}

	[[nodiscard]] const std::uint8_t* abc() noexcept
	{
		return reinterpret_cast<const std::uint8_t*>("abc");
	}
}

TEST_CASE("version comes from the build")
{
	CHECK(std::string_view(rml_version()) == "0.1.0");
}

TEST_CASE("hashing bytes writes a terminated hex string")
{
	char out[65] = {};
	REQUIRE(rml_hash_bytes(RML_HASH_SHA256, abc(), 3, out, sizeof(out)) == RML_OK);
	CHECK(std::string_view(out) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

TEST_CASE("a small output buffer is rejected with a reason")
{
	char out[10] = {};
	CHECK(rml_hash_bytes(RML_HASH_MD5, abc(), 3, out, sizeof(out)) == RML_ERR_INVALID_ARGUMENT);
	CHECK(std::string_view(rml_last_error()).find("33") != std::string_view::npos);
}

TEST_CASE("an unknown algorithm is rejected")
{
	char out[65] = {};
	CHECK(rml_hash_bytes(7, nullptr, 0, out, sizeof(out)) == RML_ERR_INVALID_ARGUMENT);
}

TEST_CASE("a missing file is an io error")
{
	char out[65] = {};
	CHECK(rml_hash_file(RML_HASH_SHA256, "/definitely/missing/rml.bin", out, sizeof(out)) == RML_ERR_IO);
}

TEST_CASE("a directory is not hashed")
{
	const TempDirectory dir("rml native dir");
	char out[65] = {};
	CHECK(rml_hash_file(RML_HASH_SHA256, rml::platform::to_utf8(dir.path()).c_str(), out, sizeof(out)) == RML_ERR_IO);
	CHECK(std::string_view(rml_last_error()).find("Not a file") != std::string_view::npos);
}

TEST_CASE("files with non-ascii paths hash correctly")
{
	const TempDirectory dir(std::filesystem::path(u8"rml native Ação ✓"));
	const auto file = dir.write(std::filesystem::path(u8"mods ção.bin"), "abc");
	char out[33] = {};
	REQUIRE(rml_hash_file(RML_HASH_MD5, file.c_str(), out, sizeof(out)) == RML_OK);
	CHECK(std::string_view(out) == "900150983cd24fb0d6963f7d28e17f72");
}

TEST_CASE("async hashing reports through the callback")
{
	const TempDirectory dir("rml native async");
	const auto [status, text] = hash_file_async(RML_HASH_SHA256, dir.write("abc.bin", "abc"));
	CHECK(status == RML_OK);
	CHECK(text == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

TEST_CASE("async hashing of a missing file reports the error text")
{
	const auto [status, text] = hash_file_async(RML_HASH_MD5, "/definitely/missing/rml.bin");
	CHECK(status == RML_ERR_IO);
	CHECK(text.find("missing") != std::string::npos);
}

TEST_CASE("the os reduce motion setting is reported or unknown")
{
	const auto reduce = rml_os_reduce_motion();
	CHECK((reduce == -1 || reduce == 0 || reduce == 1));
}
