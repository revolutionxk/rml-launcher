#include "rml/rml.h"
#include "support.hpp"
#include "zip/entry_path.hpp"
#include "zip/extract.hpp"
#include "zip_builder.hpp"

#include <atomic>
#include <chrono>
#include <cstdint>
#include <doctest/doctest.h>
#include <filesystem>
#include <fstream>
#include <future>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>

using namespace std::chrono_literals;
using rml::testing::TempDirectory;
using rml::testing::ZipEntry;

namespace
{
	struct Finished
	{
		std::int32_t status;
		std::string text;
	};

	std::promise<Finished>* g_finished = nullptr;
	std::atomic<std::uint64_t> g_progress_done{0};
	std::atomic<std::uint64_t> g_progress_total{0};

	void on_progress(const std::uint64_t done, const std::uint64_t total)
	{
		g_progress_done = done;
		g_progress_total = total;
	}

	void on_finished(const std::int32_t status, char* text)
	{
		g_finished->set_value({status, text != nullptr ? std::string(text) : std::string()});
		rml_free(text);
	}

	[[nodiscard]] std::string archive(const TempDirectory& dir, const std::vector<ZipEntry>& entries)
	{
		return dir.write("package.zip", rml::testing::as_text(rml::testing::stored_zip(entries)));
	}

	[[nodiscard]] std::string read(const std::filesystem::path& path)
	{
		std::ifstream file(path, std::ios::binary);
		return {std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
	}

	[[nodiscard]] auto extract(const std::string& zip, const std::filesystem::path& destination)
	{
		return rml::zip::extract(rml::platform::path_from_utf8(zip), destination, nullptr);
	}
}

TEST_CASE("entry names are normalised or refused")
{
	using rml::zip::safe_entry_path;
	CHECK(safe_entry_path("content/fonts/a.ttf") == "content/fonts/a.ttf");
	CHECK(safe_entry_path("content\\avatar\\x.png") == "content/avatar/x.png");
	CHECK(safe_entry_path("./a//b/") == "a/b");
	CHECK(safe_entry_path("dir/") == "dir");
	CHECK_FALSE(safe_entry_path("../evil.txt"));
	CHECK_FALSE(safe_entry_path("a/../../x.txt"));
	CHECK_FALSE(safe_entry_path("/abs.txt"));
	CHECK_FALSE(safe_entry_path("\\abs.txt"));
	CHECK_FALSE(safe_entry_path("C:/drive.txt"));
	CHECK_FALSE(safe_entry_path("C:\\drive.txt"));
	CHECK_FALSE(safe_entry_path(std::string_view("nul\0name", 8)));
}

TEST_CASE("an archive extracts its files and folders and reports them as json")
{
	const TempDirectory dir("rml native zip");
	const auto zip = archive(dir, {{"RobloxStudioBeta.exe", "exe"}, {"content/", "", 040755}, {"content/fonts/a.ttf", "font"}});
	const auto destination = dir.path() / "out";
	std::promise<Finished> promise;
	g_finished = &promise;
	auto future = promise.get_future();
	REQUIRE(rml_zip_extract_async(zip.c_str(), rml::platform::to_utf8(destination).c_str(), on_progress, on_finished) == RML_OK);
	REQUIRE(future.wait_for(10s) == std::future_status::ready);
	const auto [status, text] = future.get();
	CHECK(status == RML_OK);
	CHECK(text == R"({"bytes":7,"files":[{"path":"RobloxStudioBeta.exe","size":3},{"path":"content/fonts/a.ttf","size":4}]})");
	CHECK(read(destination / "RobloxStudioBeta.exe") == "exe");
	CHECK(read(destination / "content" / "fonts" / "a.ttf") == "font");
	CHECK(g_progress_done == 7);
	CHECK(g_progress_total == 7);
}

TEST_CASE("backslash names extract into folders")
{
	const TempDirectory dir("rml native zip backslash");
	const auto result = extract(archive(dir, {{"content\\avatar\\x.png", "png"}}), dir.path() / "out");
	REQUIRE(result.has_value());
	CHECK(read(dir.path() / "out" / "content" / "avatar" / "x.png") == "png");
}

TEST_CASE("an unsafe name refuses the whole archive before writing")
{
	const TempDirectory dir("rml native zip unsafe");
	const auto result = extract(archive(dir, {{"ok.txt", "ok"}, {"../evil.txt", "evil"}}), dir.path() / "out");
	REQUIRE_FALSE(result.has_value());
	CHECK(result.error().message.find("Unsafe path") != std::string::npos);
	CHECK_FALSE(std::filesystem::exists(dir.path() / "out" / "ok.txt"));
	CHECK_FALSE(std::filesystem::exists(dir.path() / "evil.txt"));
}

TEST_CASE("a damaged entry fails with its name")
{
	const TempDirectory dir("rml native zip crc");
	const auto result = extract(archive(dir, {{"data.bin", "payload", 0100644, true}}), dir.path() / "out");
	REQUIRE_FALSE(result.has_value());
	CHECK(result.error().message.find("data.bin") != std::string::npos);
	CHECK(result.error().message.find("corrupted") != std::string::npos);
}

TEST_CASE("a file that is not a zip fails")
{
	const TempDirectory dir("rml native zip text");
	const auto result = extract(dir.write("notes.zip", "hello"), dir.path() / "out");
	REQUIRE_FALSE(result.has_value());
	CHECK(result.error().message.find("Not a zip archive") != std::string::npos);
}

TEST_CASE("extraction works in folders with non-ascii names")
{
	const TempDirectory dir(std::filesystem::path(u8"rml native zip Ação ✓"));
	const auto result = extract(archive(dir, {{"ção.txt", "ok"}}), dir.path() / u8"saída");
	REQUIRE(result.has_value());
	CHECK(read(dir.path() / u8"saída" / u8"ção.txt") == "ok");
}

TEST_CASE("the async call reports errors through the callback")
{
	const TempDirectory dir("rml native zip async error");
	const auto zip = dir.write("notes.zip", "hello");
	std::promise<Finished> promise;
	g_finished = &promise;
	auto future = promise.get_future();
	REQUIRE(rml_zip_extract_async(zip.c_str(), rml::platform::to_utf8(dir.path() / "out").c_str(), nullptr, on_finished) == RML_OK);
	REQUIRE(future.wait_for(10s) == std::future_status::ready);
	const auto [status, text] = future.get();
	CHECK(status == RML_ERR_IO);
	CHECK(text.find("Not a zip archive") != std::string::npos);
}

TEST_CASE("the async call needs an archive, a destination and a callback")
{
	CHECK(rml_zip_extract_async(nullptr, "out", nullptr, on_finished) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_zip_extract_async("a.zip", "out", nullptr, nullptr) == RML_ERR_INVALID_ARGUMENT);
}

#if !defined(_WIN32)
TEST_CASE("file modes and links inside the destination are restored")
{
	const TempDirectory dir("rml native zip posix");
	const auto zip = archive(dir, {{"RobloxStudio.app/Contents/MacOS/RobloxStudio", "bin", 0100755}, {"RobloxStudio.app/Contents/Frameworks/Current", "A", 0120777}});
	const auto out = dir.path() / "out";
	const auto result = extract(zip, out);
	REQUIRE(result.has_value());
	const auto status = std::filesystem::status(out / "RobloxStudio.app" / "Contents" / "MacOS" / "RobloxStudio");
	CHECK((status.permissions() & std::filesystem::perms::owner_exec) != std::filesystem::perms::none);
	const auto link = out / "RobloxStudio.app" / "Contents" / "Frameworks" / "Current";
	CHECK(std::filesystem::is_symlink(link));
	CHECK(std::filesystem::read_symlink(link) == "A");
}

TEST_CASE("links that point outside the destination are refused")
{
	const TempDirectory dir("rml native zip posix link");
	const auto result = extract(archive(dir, {{"evil", "../../outside", 0120777}}), dir.path() / "out");
	REQUIRE_FALSE(result.has_value());
	CHECK(result.error().message.find("Unsafe link") != std::string::npos);
}
#endif
