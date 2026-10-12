#pragma once

#include <optional>

namespace rml::os
{
	[[nodiscard]] std::optional<bool> reduce_motion() noexcept;
}
