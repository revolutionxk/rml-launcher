#include "process/process.hpp"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <ranges>
#include <signal.h>
#include <string>
#include <system_error>
#include <vector>

namespace rml::process
{
	[[nodiscard]] static bool is_pid(const std::string& name) noexcept
	{
		return !name.empty() && std::ranges::all_of(name, [](const char character) {
			return character >= '0' && character <= '9';
		});
	}

	[[nodiscard]] static std::string matching_argument(const std::filesystem::path& process, const std::string_view executable_name)
	{
		std::ifstream file(process / "cmdline", std::ios::binary);
		const std::string command{std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
		for (const auto argument : std::views::split(command, '\0'))
		{
			const std::string_view text(argument.begin(), argument.end());
			if (!text.empty() && same_name(file_name(text), executable_name))
				return std::string(text);
		}
		return {};
	}

	std::expected<std::vector<Process>, Error> find(const std::string_view executable_name)
	{
		std::error_code ec;
		std::filesystem::directory_iterator entries("/proc", ec);
		if (ec)
			return fail("Can't list processes");
		std::vector<Process> processes;
		for (const auto& entry : entries)
		{
			const auto name = entry.path().filename().string();
			if (!is_pid(name))
				continue;
			auto path = matching_argument(entry.path(), executable_name);
			if (!path.empty())
				processes.push_back({std::stoll(name), std::move(path)});
		}
		return processes;
	}

	std::expected<void, Error> close(const std::int64_t pid)
	{
		if (::kill(static_cast<pid_t>(pid), SIGTERM) != 0)
			return fail("Can't signal process " + std::to_string(pid));
		return {};
	}

	std::expected<void, Error> kill(const std::int64_t pid)
	{
		if (::kill(static_cast<pid_t>(pid), SIGKILL) != 0)
			return fail("Can't stop process " + std::to_string(pid));
		return {};
	}
}
