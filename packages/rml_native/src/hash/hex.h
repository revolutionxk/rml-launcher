#pragma once

#include <cstdint>
#include <span>
#include <string>

namespace rml::hash {

std::string to_hex(std::span<const std::uint8_t> bytes);

}
