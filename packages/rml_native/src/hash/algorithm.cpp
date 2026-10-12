#include "hash/algorithm.hpp"

#include "hash/hasher.hpp"
#include "hash/md5.hpp"
#include "hash/sha256.hpp"

#include <utility>

namespace rml::hash
{
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
