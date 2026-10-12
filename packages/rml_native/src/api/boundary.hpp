#pragma once

#include "error.hpp"
#include "rml/rml.h"

#include <cstdint>
#include <exception>
#include <expected>
#include <string>
#include <string_view>
#include <type_traits>
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
	void write_terminated(std::string_view text, char* out) noexcept;
	[[nodiscard]] char* owned_copy(std::string_view text) noexcept;
	[[nodiscard]] Outcome deliver_text(std::string_view text, char** out);

	template<typename Body>
	[[nodiscard]] std::invoke_result_t<Body> attempt(Body&& body) noexcept
	{
		try
		{
			return std::forward<Body>(body)();
		}
		catch (const std::exception& exception)
		{
			return std::unexpected(Failure{RML_ERR_INTERNAL, exception.what()});
		}
		catch (...)
		{
			return std::unexpected(Failure{RML_ERR_INTERNAL, "Unknown error"});
		}
	}

	template<typename Body>
	[[nodiscard]] std::int32_t guarded(Body&& body) noexcept
	{
		const auto outcome = attempt(std::forward<Body>(body));
		return outcome ? RML_OK : record(outcome.error().status, outcome.error().message);
	}
}
