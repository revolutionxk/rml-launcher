#include "process/process.hpp"

#include "api/boundary.hpp"
#include "api/json.hpp"
#include "rml/rml.h"

#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace rml::api
{
	[[nodiscard]] static std::string processes_json(const std::vector<process::Process>& processes)
	{
		std::string text = "[";
		for (std::size_t index = 0; index < processes.size(); ++index)
		{
			if (index > 0)
				text += ',';
			text += "{\"pid\":" + std::to_string(processes[index].pid) + ",\"path\":" + json::quote(processes[index].path) + "}";
		}
		return text + "]";
	}

	[[nodiscard]] static bool valid_pid(const std::int64_t pid) noexcept
	{
		return pid > 0 && pid <= std::numeric_limits<std::int32_t>::max();
	}

	extern "C"
	{
		RML_API std::int32_t rml_processes(const char* executable_name, char** out_json)
		{
			return guarded([&]() -> Outcome {
				if (executable_name == nullptr || *executable_name == '\0' || out_json == nullptr)
					return invalid_argument("Executable name and output are required");
				auto found = process::find(executable_name);
				if (!found)
					return io_error(std::move(found.error()));
				return deliver_text(processes_json(*found), out_json);
			});
		}

		RML_API std::int32_t rml_process_close(const std::int64_t pid)
		{
			return guarded([&]() -> Outcome {
				if (!valid_pid(pid))
					return invalid_argument("Process id is out of range");
				auto closed = process::close(pid);
				if (!closed)
					return io_error(std::move(closed.error()));
				return {};
			});
		}

		RML_API std::int32_t rml_process_kill(const std::int64_t pid)
		{
			return guarded([&]() -> Outcome {
				if (!valid_pid(pid))
					return invalid_argument("Process id is out of range");
				auto killed = process::kill(pid);
				if (!killed)
					return io_error(std::move(killed.error()));
				return {};
			});
		}
	}
}
