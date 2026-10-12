#include "api/boundary.hpp"
#include "rml/rml.h"

#include <cstdlib>

extern "C"
{
	const char* rml_version()
	{
		return RML_NATIVE_VERSION;
	}

	const char* rml_last_error()
	{
		return rml::api::last_error();
	}

	void rml_free(void* pointer)
	{
		std::free(pointer);
	}
}
