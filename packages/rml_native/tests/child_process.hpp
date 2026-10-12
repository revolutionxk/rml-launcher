#pragma once

#include <chrono>
#include <cstdint>
#include <filesystem>

namespace rml::testing
{
	class ChildProcess
	{
	public:
		explicit ChildProcess(const std::filesystem::path& program);
		ChildProcess(const ChildProcess&) = delete;
		ChildProcess& operator=(const ChildProcess&) = delete;
		~ChildProcess();

		[[nodiscard]] std::int64_t pid() const noexcept;
		[[nodiscard]] bool wait_for_exit(std::chrono::milliseconds timeout);

	private:
		std::int64_t m_pid = 0;
		[[maybe_unused]] void* m_handle = nullptr;
		bool m_exited = false;
	};
}
