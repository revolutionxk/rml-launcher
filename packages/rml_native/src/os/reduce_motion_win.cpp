#include "os/reduce_motion.hpp"

#include <windows.h>

namespace rml::os
{
	std::optional<bool> reduce_motion() noexcept
	{
		BOOL animations = TRUE;
		if (!SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0))
			return std::nullopt;
		return !animations;
	}
}
