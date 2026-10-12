cmake_minimum_required(VERSION 3.24)
project(rml_native VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_OBJCXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(RML_NATIVE_TESTS "Build the rml_native tests" OFF)

find_package(Threads REQUIRED)

if(APPLE)
  enable_language(OBJCXX)
  set(RML_OS_SOURCES src/os/accessibility_mac.mm)
  set(RML_OS_LIBRARIES "-framework AppKit")
elseif(WIN32)
  set(RML_OS_SOURCES src/os/accessibility_win.cpp)
  set(RML_OS_LIBRARIES user32)
else()
  set(RML_OS_SOURCES src/os/accessibility_other.cpp)
  set(RML_OS_LIBRARIES "")
endif()

add_library(rml_objects OBJECT
  src/error.cpp
  src/hash/hex.cpp
  src/hash/sha256.cpp
  src/hash/md5.cpp
  src/hash/hash_file.cpp
  src/api/rml_api.cpp
  ${RML_OS_SOURCES}
)
target_include_directories(rml_objects PUBLIC include src)
target_compile_definitions(rml_objects PUBLIC RML_BUILDING RML_NATIVE_VERSION="${PROJECT_VERSION}")
target_link_libraries(rml_objects PUBLIC Threads::Threads ${RML_OS_LIBRARIES})
if(MSVC)
  target_compile_options(rml_objects PUBLIC /utf-8 /W4)
else()
  target_compile_options(rml_objects PUBLIC -Wall -Wextra)
endif()

add_library(rml_native SHARED $<TARGET_OBJECTS:rml_objects>)
target_link_libraries(rml_native PRIVATE Threads::Threads ${RML_OS_LIBRARIES})

install(TARGETS rml_native
  RUNTIME DESTINATION lib
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)

if(RML_NATIVE_TESTS)
  include(cmake/CPM.cmake)
  CPMAddPackage("gh:doctest/doctest@2.5.3")
  enable_testing()
  add_executable(rml_native_tests tests/main.cpp tests/hash_test.cpp tests/api_test.cpp)
  target_link_libraries(rml_native_tests PRIVATE rml_objects doctest::doctest)
  add_test(NAME rml_native_tests COMMAND rml_native_tests)
endif()
