#include "hash/algorithm.hpp"

#include "hash/hasher.hpp"
#include "hash/md5.hpp"
#include "hash/sha256.hpp"
#include "platform/path.hpp"

#include <fstream>
#include <system_error>
#include <utility>
#include <vector>

namespace rml::hash
{
	static constexpr std::size_t file_chunk_size = 1 << 20;

	template<Hasher H>
	[[nodiscard]] static std::expected<std::string, Error> hash_file(const std::filesystem::path& path)
	{
		std::error_code ec;
		if (!std::filesystem::is_regular_file(path, ec))
			return fail("Not a file: " + platform::to_utf8(path));

		std::ifstream file(path, std::ios::binary);
		if (!file)
			return fail("Can't open " + platform::to_utf8(path));

		H hasher;
		std::vector<char> chunk(file_chunk_size);
		while (file)
		{
			file.read(chunk.data(), std::ssize(chunk));
			hasher.update(std::as_bytes(std::span(chunk).first(static_cast<std::size_t>(file.gcount()))));
		}

		if (file.bad())
			return fail("Can't read " + platform::to_utf8(path));

		return to_hex(hasher.finish());
	}

	std::string hash_bytes(const Algorithm algorithm, const std::span<const std::byte> data)
	{
		switch (algorithm)
		{
		case Algorithm::Md5: return hash_bytes<Md5>(data);
		case Algorithm::Sha256: return hash_bytes<Sha256>(data);
		}
		std::unreachable();
	}

	std::expected<std::string, Error> hash_file(const Algorithm algorithm, const std::filesystem::path& path)
	{
		switch (algorithm)
		{
		case Algorithm::Md5: return hash_file<Md5>(path);
		case Algorithm::Sha256: return hash_file<Sha256>(path);
		}
		std::unreachable();
	}
}
