#include "rml/rml.h"
#include "support.hpp"

#include <cstdint>
#include <doctest/doctest.h>
#include <filesystem>
#include <string>

using rml::testing::TempDirectory;

TEST_CASE("free space is reported for an existing folder")
{
	const TempDirectory dir("rml native disk");
	std::uint64_t bytes = 0;
	REQUIRE(rml_disk_free(dir.utf8().c_str(), &bytes) == RML_OK);
	CHECK(bytes > 0);
}

TEST_CASE("free space of a missing folder comes from its nearest existing parent")
{
	const TempDirectory dir(std::filesystem::path(u8"rml native disk Ação"));
	const auto missing = rml::platform::to_utf8(dir.path() / "Studio" / "main" / "builds");
	std::uint64_t bytes = 0;
	REQUIRE(rml_disk_free(missing.c_str(), &bytes) == RML_OK);
	CHECK(bytes > 0);
}

TEST_CASE("free space needs a path and somewhere to write it")
{
	std::uint64_t bytes = 0;
	CHECK(rml_disk_free(nullptr, &bytes) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_disk_free("", &bytes) == RML_ERR_INVALID_ARGUMENT);
	const TempDirectory dir("rml native disk out");
	CHECK(rml_disk_free(dir.utf8().c_str(), nullptr) == RML_ERR_INVALID_ARGUMENT);
}
