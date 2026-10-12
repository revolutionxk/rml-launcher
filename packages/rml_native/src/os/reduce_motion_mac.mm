#include "os/reduce_motion.hpp"

#import <AppKit/AppKit.h>

namespace rml::os
{
	std::optional<bool> reduce_motion() noexcept
	{
		@autoreleasepool
		{
			return static_cast<bool>(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion);
		}
	}
}
