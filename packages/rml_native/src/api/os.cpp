#include "os/reduce_motion.hpp"
#include "rml/rml.h"

#include <cstdint>

extern "C"
{
	std::int32_t rml_os_reduce_motion()
	{
		const auto reduce = rml::os::reduce_motion();
		return reduce ? static_cast<std::int32_t>(*reduce) : -1;
	}
}
