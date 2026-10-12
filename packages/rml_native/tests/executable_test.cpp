#include "exe/pe_version.hpp"
#include "pe_builder.hpp"
#include "platform/text.hpp"
#include "rml/rml.h"
#include "support.hpp"

#include <cstdint>
#include <doctest/doctest.h>
#include <string>
#include <string_view>

using rml::testing::TempDirectory;

namespace
{
	struct Described
	{
		std::int32_t status;
		std::string json;
	};

	[[nodiscard]] Described describe(const std::string& path)
	{
		char* json = nullptr;
		const auto status = rml_executable_info(path.c_str(), &json);
		Described described{status, json != nullptr ? std::string(json) : std::string()};
		rml_free(json);
		return described;
	}

	[[nodiscard]] std::string studio_executable(const TempDirectory& dir)
	{
		const auto version = rml::testing::version_info(rml::testing::fixed_info(0, 690, 0, 65535), u"0, 690, 0, 6900613");
		return dir.write("RobloxStudioBeta.exe", rml::testing::as_text(rml::testing::portable_executable(version)));
	}
}

TEST_CASE("the file version string comes from the version resource")
{
	const TempDirectory dir("rml native pe string");
	const auto version = rml::exe::file_version(rml::platform::path_from_utf8(studio_executable(dir)));
	REQUIRE(version.has_value());
	CHECK(*version == "0, 690, 0, 6900613");
}

TEST_CASE("the fixed file version is used when there is no string table")
{
	const TempDirectory dir("rml native pe fixed");
	const auto image = rml::testing::portable_executable(rml::testing::version_info(rml::testing::fixed_info(1, 2, 3, 4), u""));
	const auto path = dir.write("tool.exe", rml::testing::as_text(image));
	const auto version = rml::exe::file_version(rml::platform::path_from_utf8(path));
	REQUIRE(version.has_value());
	CHECK(*version == "1.2.3.4");
}

TEST_CASE("executable info returns the version as json")
{
	const TempDirectory dir(std::filesystem::path(u8"rml native pe Ação"));
	const auto [status, json] = describe(studio_executable(dir));
	CHECK(status == RML_OK);
	CHECK(json == R"({"version":"0, 690, 0, 6900613"})");
}

TEST_CASE("a file that is not an executable is an io error")
{
	const TempDirectory dir("rml native pe text");
	const auto [status, json] = describe(dir.write("notes.txt", "hello"));
	CHECK(status == RML_ERR_IO);
	CHECK(std::string_view(rml_last_error()).find("Not a Windows executable") != std::string_view::npos);
}

TEST_CASE("a truncated executable is rejected without reading past the end")
{
	const TempDirectory dir("rml native pe short");
	const auto image = rml::testing::portable_executable(rml::testing::version_info(rml::testing::fixed_info(1, 2, 3, 4), u"1.2.3.4"));
	const auto [status, json] = describe(dir.write("short.exe", rml::testing::as_text(image).substr(0, 0x210)));
	CHECK(status == RML_ERR_IO);
}

TEST_CASE("an executable without resources is rejected")
{
	const TempDirectory dir("rml native pe bare");
	auto image = rml::testing::portable_executable(rml::testing::version_info(rml::testing::fixed_info(1, 2, 3, 4), u""));
	rml::testing::put_u32(image, 0x58 + 128, 0);
	const auto [status, json] = describe(dir.write("bare.exe", rml::testing::as_text(image)));
	CHECK(status == RML_ERR_IO);
	CHECK(std::string_view(rml_last_error()).find("no version resource") != std::string_view::npos);
}

TEST_CASE("executable info needs a path and an output")
{
	char* json = nullptr;
	CHECK(rml_executable_info(nullptr, &json) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_executable_info("x.exe", nullptr) == RML_ERR_INVALID_ARGUMENT);
}

TEST_CASE("utf-16 text converts to utf-8")
{
	CHECK(rml::platform::utf16_to_utf8(u"Ação ✓") == "Ação ✓");
	CHECK(rml::platform::utf16_to_utf8(u"\U0001F600") == "\xF0\x9F\x98\x80");
	CHECK(rml::platform::utf16_to_utf8(std::u16string_view(u"\xD800", 1)) == "\xEF\xBF\xBD");
}

#if defined(__APPLE__)
TEST_CASE("bundle info is read from Info.plist")
{
	const TempDirectory dir("rml native bundle");
	static_cast<void>(dir.write("RobloxStudio.app/Contents/Info.plist", R"(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.Roblox.RobloxStudio</string>
	<key>CFBundleShortVersionString</key>
	<string>0.700.1</string>
	<key>CFBundleExecutable</key>
	<string>RobloxStudio</string>
</dict>
</plist>
)"));
	const auto [status, json] = describe(rml::platform::to_utf8(dir.path() / "RobloxStudio.app"));
	CHECK(status == RML_OK);
	CHECK(json == R"({"identifier":"com.Roblox.RobloxStudio","version":"0.700.1","executable":"RobloxStudio"})");
}

TEST_CASE("a damaged Info.plist is an io error")
{
	const TempDirectory dir("rml native bundle damaged");
	static_cast<void>(dir.write("Broken.app/Contents/Info.plist", "not a plist"));
	const auto [status, json] = describe(rml::platform::to_utf8(dir.path() / "Broken.app"));
	CHECK(status == RML_ERR_IO);
}
#else
TEST_CASE("bundles are only read on macOS")
{
	const TempDirectory dir("rml native bundle other");
	static_cast<void>(dir.write("RobloxStudio.app/Contents/Info.plist", "<plist/>"));
	const auto [status, json] = describe(rml::platform::to_utf8(dir.path() / "RobloxStudio.app"));
	CHECK(status == RML_ERR_IO);
	CHECK(std::string_view(rml_last_error()).find("macOS only") != std::string_view::npos);
}
#endif

#if defined(_WIN32)
TEST_CASE("a system library has a file version")
{
	const auto [status, json] = describe("C:\\Windows\\System32\\kernel32.dll");
	CHECK(status == RML_OK);
	CHECK(json.starts_with(R"({"version":")"));
}
#endif
