#include "child_process.hpp"
#include "process/process.hpp"
#include "rml/rml.h"

#include <chrono>
#include <cstdint>
#include <doctest/doctest.h>
#include <string>
#include <string_view>
#include <thread>

using namespace std::chrono_literals;
using rml::testing::ChildProcess;

namespace
{
#if defined(_WIN32)
	constexpr std::string_view sleeper_name = "rml_sleeper.exe";
#else
	constexpr std::string_view sleeper_name = "rml_sleeper";
#endif

	[[nodiscard]] std::string listing()
	{
		char* json = nullptr;
		REQUIRE(rml_processes(std::string(sleeper_name).c_str(), &json) == RML_OK);
		std::string text(json);
		rml_free(json);
		return text;
	}

	[[nodiscard]] bool listed(const std::int64_t pid, const std::chrono::milliseconds timeout)
	{
		const auto needle = "\"pid\":" + std::to_string(pid) + ",";
		const auto deadline = std::chrono::steady_clock::now() + timeout;
		while (std::chrono::steady_clock::now() < deadline)
		{
			if (listing().find(needle) != std::string::npos)
				return true;
			std::this_thread::sleep_for(50ms);
		}
		return false;
	}

	[[nodiscard]] bool close_when_ready(const std::int64_t pid, const std::chrono::milliseconds timeout)
	{
		const auto deadline = std::chrono::steady_clock::now() + timeout;
		while (std::chrono::steady_clock::now() < deadline)
		{
			if (rml_process_close(pid) == RML_OK)
				return true;
			std::this_thread::sleep_for(50ms);
		}
		return false;
	}
}

TEST_CASE("names match without case and paths split on both separators")
{
	CHECK(rml::process::same_name("RobloxStudioBeta.EXE", "robloxstudiobeta.exe"));
	CHECK_FALSE(rml::process::same_name("RobloxStudio", "RobloxStudioBeta.exe"));
	CHECK(rml::process::file_name("C:\\Roblox\\Versions\\version-1\\RobloxStudioBeta.exe") == "RobloxStudioBeta.exe");
	CHECK(rml::process::file_name("/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio") == "RobloxStudio");
	CHECK(rml::process::file_name("RobloxStudio") == "RobloxStudio");
}

TEST_CASE("a running program is listed by its executable name")
{
	ChildProcess child(RML_SLEEPER);
	REQUIRE(child.pid() != 0);
	CHECK(listed(child.pid(), 5s));
	CHECK(listing().find("rml_sleeper") != std::string::npos);
}

TEST_CASE("closing asks the program to quit")
{
	ChildProcess child(RML_SLEEPER);
	REQUIRE(listed(child.pid(), 5s));
	CHECK(close_when_ready(child.pid(), 5s));
	CHECK(child.wait_for_exit(5s));
}

TEST_CASE("killing stops the program")
{
	ChildProcess child(RML_SLEEPER);
	REQUIRE(listed(child.pid(), 5s));
	CHECK(rml_process_kill(child.pid()) == RML_OK);
	CHECK(child.wait_for_exit(5s));
}

TEST_CASE("a process that is gone can't be closed or killed")
{
	std::int64_t pid = 0;
	{
		ChildProcess child(RML_SLEEPER);
		pid = child.pid();
		REQUIRE(listed(pid, 5s));
		REQUIRE(rml_process_kill(pid) == RML_OK);
		REQUIRE(child.wait_for_exit(5s));
	}
	CHECK(rml_process_kill(pid) == RML_ERR_IO);
	CHECK(rml_process_close(pid) == RML_ERR_IO);
}

TEST_CASE("process calls check their arguments")
{
	char* json = nullptr;
	CHECK(rml_processes(nullptr, &json) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_processes("", &json) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_processes("RobloxStudioBeta.exe", nullptr) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_process_close(0) == RML_ERR_INVALID_ARGUMENT);
	CHECK(rml_process_kill(-1) == RML_ERR_INVALID_ARGUMENT);
}

TEST_CASE("an unknown name lists nothing")
{
	char* json = nullptr;
	REQUIRE(rml_processes("rml-definitely-not-running", &json) == RML_OK);
	CHECK(std::string_view(json) == "[]");
	rml_free(json);
}
