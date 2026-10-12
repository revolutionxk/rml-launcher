#include "platform/path.hpp"
#include "process/process.hpp"

#include <Windows.h>
#include <filesystem>
#include <memory>
#include <string>
#include <tlhelp32.h>
#include <type_traits>
#include <vector>

namespace rml::process
{
	namespace
	{
		struct HandleCloser
		{
			void operator()(const HANDLE handle) const noexcept
			{
				CloseHandle(handle);
			}
		};

		using Handle = std::unique_ptr<std::remove_pointer_t<HANDLE>, HandleCloser>;

		struct WindowSearch
		{
			DWORD pid;
			std::vector<HWND> visible;
			std::vector<HWND> other;
		};
	}

	[[nodiscard]] static std::string image_path(const DWORD pid)
	{
		const Handle process(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid));
		if (!process)
			return {};
		std::wstring buffer(32768, L'\0');
		auto size = static_cast<DWORD>(buffer.size());
		if (!QueryFullProcessImageNameW(process.get(), 0, buffer.data(), &size))
			return {};
		buffer.resize(size);
		return platform::to_utf8(std::filesystem::path(buffer));
	}

	std::expected<std::vector<Process>, Error> find(const std::string_view executable_name)
	{
		const auto raw = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (raw == INVALID_HANDLE_VALUE)
			return fail("Can't list processes");
		const Handle snapshot(raw);
		PROCESSENTRY32W entry{};
		entry.dwSize = sizeof(entry);
		std::vector<Process> processes;
		for (auto more = Process32FirstW(snapshot.get(), &entry); more; more = Process32NextW(snapshot.get(), &entry))
		{
			if (same_name(platform::to_utf8(std::filesystem::path(entry.szExeFile)), executable_name))
				processes.push_back({static_cast<std::int64_t>(entry.th32ProcessID), image_path(entry.th32ProcessID)});
		}
		return processes;
	}

	static BOOL CALLBACK collect_window(const HWND window, const LPARAM context)
	{
		auto& search = *reinterpret_cast<WindowSearch*>(context);
		DWORD owner = 0;
		GetWindowThreadProcessId(window, &owner);
		if (owner != search.pid)
			return TRUE;
		if (IsWindowVisible(window) && GetWindow(window, GW_OWNER) == nullptr)
			search.visible.push_back(window);
		else
			search.other.push_back(window);
		return TRUE;
	}

	std::expected<void, Error> close(const std::int64_t pid)
	{
		WindowSearch search{static_cast<DWORD>(pid), {}, {}};
		EnumWindows(collect_window, reinterpret_cast<LPARAM>(&search));
		const auto& targets = search.visible.empty() ? search.other : search.visible;
		if (targets.empty())
			return fail("Process " + std::to_string(pid) + " has no window to close");
		for (const auto window : targets)
			PostMessageW(window, WM_CLOSE, 0, 0);
		return {};
	}

	std::expected<void, Error> kill(const std::int64_t pid)
	{
		const Handle process(OpenProcess(PROCESS_TERMINATE, FALSE, static_cast<DWORD>(pid)));
		if (!process)
			return fail("Can't open process " + std::to_string(pid));
		if (!TerminateProcess(process.get(), 1))
			return fail("Can't stop process " + std::to_string(pid));
		return {};
	}
}
