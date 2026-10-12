#include "api/json.hpp"

#include <doctest/doctest.h>
#include <string_view>

using rml::api::json::quote;

TEST_CASE("json text is quoted with escapes")
{
	CHECK(quote("Main") == R"("Main")");
	CHECK(quote(R"(C:\Users\a "b")") == R"("C:\\Users\\a \"b\"")");
	CHECK(quote("line\nnext\ttab\r") == R"("line\nnext\ttab\r")");
	CHECK(quote(std::string_view("\x01\x1f", 2)) == R"("\u0001\u001f")");
}

TEST_CASE("json text keeps utf-8 as it is")
{
	CHECK(quote("Ação ✓") == "\"Ação ✓\"");
}
