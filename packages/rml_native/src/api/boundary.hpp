#pragma once

#include "error.hpp"
#include "rml/rml.h"

#include <cstdint>
#include <exception>
#include <expected>
#include <string>
#include <string_view>
#include <utility>

namespace rml::api
{
	struct Failure
	{
		rml_status status;
		std::string message;
	};

	using Outcome = std::expected<void, Failure>;

	[[nodiscard]] std::unexpected<Failure> invalid_argument(std::string message);
	[[nodiscard]] std::unexpected<Failure> io_error(Error error);

	[[nodiscard]] const char* last_error() noexcept;
	[[nodiscard]] std::int32_t record(rml_status status, std::string_view message);

	template<typename Body>
	[[nodiscard]] std::int32_t guarded(Body&& body) noexcept
	{
		try
		{
			if (const Outcome outcome = std::forward<Body>(body)(); !outcome)
				return record(outcome.error().status, outcome.error().message);
			return RML_OK;
		}
		catch (const std::exception& exception)
		{
			return record(RML_ERR_INTERNAL, exception.what());
		}
		catch (...)
		{
			return record(RML_ERR_INTERNAL, "Unknown error");
		}
	}
}
