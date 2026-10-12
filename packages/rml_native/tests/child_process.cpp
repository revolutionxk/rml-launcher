#include "child_process.hpp"

#if defined(_WIN32)
	#include <Windows.h>
	#include <string>
#else
	#include <signal.h>
	#include <spawn.h>
	#include <string>
	#include <sys/wait.h>
	#include <thread>
	#include <unistd.h>

extern char** environ;
#endif

namespace rml::testing
{
	ChildProcess::ChildProcess(const std::filesystem::path& program)
	{
#if defined(_WIN32)
		STARTUPINFOW startup{};
		startup.cb = sizeof(startup);
		PROCESS_INFORMATION info{};
		std::wstring command = L"\"" + program.wstring() + L"\"";
		if (CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &info))
		{
			CloseHandle(info.hThread);
			m_handle = info.hProcess;
			m_pid = info.dwProcessId;
		}
#else
		const auto path = program.string();
		char* const arguments[] = {const_cast<char*>(path.c_str()), nullptr};
		pid_t pid = 0;
		if (posix_spawn(&pid, path.c_str(), nullptr, nullptr, arguments, environ) == 0)
			m_pid = pid;
#endif
	}

	ChildProcess::~ChildProcess()
	{
		if (m_pid == 0)
			return;
		if (!m_exited)
		{
#if defined(_WIN32)
			TerminateProcess(m_handle, 1);
#else
			::kill(static_cast<pid_t>(m_pid), SIGKILL);
#endif
			static_cast<void>(wait_for_exit(std::chrono::seconds(5)));
		}
#if defined(_WIN32)
		CloseHandle(m_handle);
#endif
	}

	std::int64_t ChildProcess::pid() const noexcept
	{
		return m_pid;
	}

	bool ChildProcess::wait_for_exit(const std::chrono::milliseconds timeout)
	{
		if (m_exited || m_pid == 0)
			return m_exited;
#if defined(_WIN32)
		m_exited = WaitForSingleObject(m_handle, static_cast<DWORD>(timeout.count())) == WAIT_OBJECT_0;
#else
		const auto deadline = std::chrono::steady_clock::now() + timeout;
		while (!m_exited && std::chrono::steady_clock::now() < deadline)
		{
			int status = 0;
			m_exited = waitpid(static_cast<pid_t>(m_pid), &status, WNOHANG) == m_pid;
			if (!m_exited)
				std::this_thread::sleep_for(std::chrono::milliseconds(20));
		}
#endif
		return m_exited;
	}
}
