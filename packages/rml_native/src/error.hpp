#pragma once

#include <expected>
#include <string>
#include <utility>

namespace rml
{
	struct Error
	{
		std::string message;
	};

	[[nodiscard]] inline std::unexpected<Error> fail(std::string message)
	{
		return std::unexpected(Error{std::move(message)});
	}
}
