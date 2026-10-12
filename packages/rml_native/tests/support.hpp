#pragma once

#include "platform/path.hpp"

#include <filesystem>
#include <fstream>
#include <string>
#include <string_view>
#include <system_error>

namespace rml::testing
{
	class TempDirectory
	{
	public:
		explicit TempDirectory(const std::filesystem::path& name) :
		    m_path(std::filesystem::temp_directory_path() / name)
		{
			std::error_code ec;
			std::filesystem::remove_all(m_path, ec);
			std::filesystem::create_directories(m_path);
		}

		TempDirectory(const TempDirectory&) = delete;
		TempDirectory& operator=(const TempDirectory&) = delete;

		~TempDirectory()
		{
			std::error_code ec;
			std::filesystem::remove_all(m_path, ec);
		}

		[[nodiscard]] const std::filesystem::path& path() const noexcept
		{
			return m_path;
		}

		[[nodiscard]] std::string utf8() const
		{
			return platform::to_utf8(m_path);
		}

		[[nodiscard]] std::string write(const std::filesystem::path& name, const std::string_view content) const
		{
			const auto file = m_path / name;
			std::filesystem::create_directories(file.parent_path());
			std::ofstream(file, std::ios::binary) << content;
			return platform::to_utf8(file);
		}

	private:
		std::filesystem::path m_path;
	};
}
