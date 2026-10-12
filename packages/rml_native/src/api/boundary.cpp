#include "api/boundary.hpp"

#include <cstdlib>

namespace rml::api
{
	static thread_local std::string t_last_error;

	std::unexpected<Failure> invalid_argument(std::string message)
	{
		return std::unexpected(Failure{RML_ERR_INVALID_ARGUMENT, std::move(message)});
	}

	std::unexpected<Failure> io_error(Error error)
	{
		return std::unexpected(Failure{RML_ERR_IO, std::move(error.message)});
	}

	const char* last_error() noexcept
	{
		return t_last_error.c_str();
	}

	std::int32_t record(const rml_status status, const std::string_view message)
	{
		t_last_error.assign(message);
		return status;
	}

	void write_terminated(const std::string_view text, char* out) noexcept
	{
		text.copy(out, text.size());
		out[text.size()] = '\0';
	}

	char* owned_copy(const std::string_view text) noexcept
	{
		auto* const copy = static_cast<char*>(std::malloc(text.size() + 1));
		if (copy != nullptr)
			write_terminated(text, copy);
		return copy;
	}

	Outcome deliver_text(const std::string_view text, char** out)
	{
		if (out == nullptr)
			return invalid_argument("Output pointer is null");
		*out = owned_copy(text);
		if (*out == nullptr)
			return std::unexpected(Failure{RML_ERR_INTERNAL, "Out of memory"});
		return {};
	}
}
