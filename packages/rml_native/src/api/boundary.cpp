#include "api/boundary.hpp"

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
}
