#include "process/process.hpp"

#import <AppKit/AppKit.h>
#include <algorithm>
#include <array>
#include <libproc.h>
#include <signal.h>
#include <span>
#include <vector>

namespace rml::process
{
	std::expected<std::vector<Process>, Error> find(const std::string_view executable_name)
	{
		const auto count = proc_listallpids(nullptr, 0);
		if (count <= 0)
			return fail("Can't list processes");
		std::vector<pid_t> pids(static_cast<std::size_t>(count) * 2);
		const auto listed = proc_listallpids(pids.data(), static_cast<int>(pids.size() * sizeof(pid_t)));
		if (listed <= 0)
			return fail("Can't list processes");
		std::vector<Process> processes;
		std::array<char, PROC_PIDPATHINFO_MAXSIZE> path{};
		for (const auto pid : std::span(pids).first(std::min(pids.size(), static_cast<std::size_t>(listed))))
		{
			if (pid <= 0 || proc_pidpath(pid, path.data(), static_cast<std::uint32_t>(path.size())) <= 0)
				continue;
			const std::string_view full(path.data());
			if (same_name(file_name(full), executable_name))
				processes.push_back({pid, std::string(full)});
		}
		return processes;
	}

	std::expected<void, Error> close(const std::int64_t pid)
	{
		@autoreleasepool
		{
			NSRunningApplication* const application = [NSRunningApplication runningApplicationWithProcessIdentifier:static_cast<pid_t>(pid)];
			if (application != nil)
			{
				if ([application terminate])
					return {};
				return fail("Process " + std::to_string(pid) + " didn't accept the request to quit");
			}
		}
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
