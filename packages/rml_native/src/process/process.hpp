#pragma once

#include "error.hpp"

#include <cstdint>
#include <expected>
#include <string>
#include <string_view>
#include <vector>

namespace rml::process
{
	struct Process
	{
		std::int64_t pid;
		std::string path;
	};

	[[nodiscard]] std::expected<std::vector<Process>, Error> find(std::string_view executable_name);
	[[nodiscard]] std::expected<void, Error> close(std::int64_t pid);
	[[nodiscard]] std::expected<void, Error> kill(std::int64_t pid);

	[[nodiscard]] bool same_name(std::string_view left, std::string_view right) noexcept;
	[[nodiscard]] std::string_view file_name(std::string_view path) noexcept;
}
