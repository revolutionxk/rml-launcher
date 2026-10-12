#pragma once

#include <stdint.h>

#if defined(_WIN32)
	#if defined(RML_BUILDING)
		#define RML_API __declspec(dllexport)
	#else
		#define RML_API __declspec(dllimport)
	#endif
#else
	#define RML_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C"
{
#endif

	typedef enum rml_status
	{
		RML_OK = 0,
		RML_ERR_INVALID_ARGUMENT = 1,
		RML_ERR_IO = 2,
		RML_ERR_INTERNAL = 3,
	} rml_status;

	typedef enum rml_hash_algorithm
	{
		RML_HASH_MD5 = 0,
		RML_HASH_SHA256 = 1,
	} rml_hash_algorithm;

	typedef void (*rml_text_callback)(int32_t status, char* text);

	RML_API const char* rml_version(void);

	RML_API const char* rml_last_error(void);

	RML_API void rml_free(void* pointer);

	RML_API int32_t rml_hash_bytes(int32_t algorithm, const uint8_t* data, uint64_t length, char* out_hex, uint64_t out_capacity);

	RML_API int32_t rml_hash_file(int32_t algorithm, const char* path, char* out_hex, uint64_t out_capacity);

	RML_API int32_t rml_hash_file_async(int32_t algorithm, const char* path, rml_text_callback callback);

	RML_API int32_t rml_os_reduce_motion(void);
	RML_API int32_t rml_disk_free(const char* path, uint64_t* out_bytes);
	RML_API int32_t rml_executable_info(const char* path, char** out_json);

#ifdef __cplusplus
}
#endif
