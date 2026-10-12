set(CPM_DOWNLOAD_VERSION 0.43.2)
set(CPM_DOWNLOAD_HASH 49a3bef91ceb65bb66d57255e12d1ffd22abc2f6408fa9fe4534c544a2f232aa)

if(CPM_SOURCE_CACHE)
  set(CPM_DOWNLOAD_LOCATION "${CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
elseif(DEFINED ENV{CPM_SOURCE_CACHE})
  set(CPM_DOWNLOAD_LOCATION "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
else()
  set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
endif()

get_filename_component(CPM_DOWNLOAD_LOCATION ${CPM_DOWNLOAD_LOCATION} ABSOLUTE)

foreach(cpm_attempt RANGE 3)
  if(EXISTS ${CPM_DOWNLOAD_LOCATION})
    file(SHA256 ${CPM_DOWNLOAD_LOCATION} cpm_hash)
    if("${cpm_hash}" STREQUAL "${CPM_DOWNLOAD_HASH}")
      break()
    endif()
    file(REMOVE ${CPM_DOWNLOAD_LOCATION})
  endif()
  if(cpm_attempt LESS 3)
    file(DOWNLOAD
      https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake
      ${CPM_DOWNLOAD_LOCATION}
      STATUS cpm_status
    )
  endif()
endforeach()

if(NOT EXISTS ${CPM_DOWNLOAD_LOCATION})
  message(FATAL_ERROR "Could not download CPM.cmake ${CPM_DOWNLOAD_VERSION}: ${cpm_status}")
endif()

include(${CPM_DOWNLOAD_LOCATION})
