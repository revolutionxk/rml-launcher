#include "api/boundary.hpp"
#include "rml/rml.h"

#include <cstdlib>

namespace rml::api
{
	extern "C"
	{
		RML_API const char* rml_version()
		{
			return RML_NATIVE_VERSION;
		}

		RML_API const char* rml_last_error()
		{
			return last_error();
		}

		RML_API void rml_free(void* pointer)
		{
			std::free(pointer);
		}
	}
}
