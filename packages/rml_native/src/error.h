#pragma once

#include <string_view>

namespace rml {

void set_last_error(std::string_view message);

const char* last_error();

}
