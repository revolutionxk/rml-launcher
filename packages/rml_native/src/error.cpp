#include "error.h"

#include <string>

namespace rml {

namespace {
thread_local std::string current;
}

void set_last_error(std::string_view message) { current.assign(message); }

const char* last_error() { return current.c_str(); }

}
