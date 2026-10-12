#include "os/reduce_motion.hpp"
#include "rml/rml.h"

#include <cstdint>

namespace rml::api
{
	extern "C"
	{
		RML_API std::int32_t rml_os_reduce_motion()
		{
			const auto reduce = os::reduce_motion();
			return reduce ? static_cast<std::int32_t>(*reduce) : -1;
		}
	}
}
