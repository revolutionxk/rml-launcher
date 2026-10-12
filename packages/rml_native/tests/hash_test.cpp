#include "hash/algorithm.hpp"
#include "hash/hasher.hpp"
#include "hash/md5.hpp"
#include "hash/sha256.hpp"

#include <array>
#include <cstddef>
#include <doctest/doctest.h>
#include <span>
#include <string>
#include <string_view>

namespace
{
	[[nodiscard]] std::span<const std::byte> bytes(const std::string_view text) noexcept
	{
		return std::as_bytes(std::span(text));
	}

	[[nodiscard]] std::string sha256(const std::string_view text)
	{
		return rml::hash::hash_bytes(rml::hash::Algorithm::Sha256, bytes(text));
	}

	[[nodiscard]] std::string md5(const std::string_view text)
	{
		return rml::hash::hash_bytes(rml::hash::Algorithm::Md5, bytes(text));
	}

	template<rml::hash::Hasher H>
	[[nodiscard]] std::string hash_in_two_parts(const std::span<const std::byte> data, const std::size_t split)
	{
		H hasher;
		hasher.update(data.first(split));
		hasher.update(data.subspan(split));
		return rml::hash::to_hex(hasher.finish());
	}
}

TEST_CASE("sha256 matches the FIPS 180 vectors")
{
	CHECK(sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
	CHECK(sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
	CHECK(sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
	CHECK(sha256(std::string(1'000'000, 'a')) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
}

TEST_CASE("md5 matches the RFC 1321 vectors")
{
	CHECK(md5("") == "d41d8cd98f00b204e9800998ecf8427e");
	CHECK(md5("abc") == "900150983cd24fb0d6963f7d28e17f72");
	CHECK(md5("message digest") == "f96b697d7cb7938d525a2f31aaf161d0");
	CHECK(md5("12345678901234567890123456789012345678901234567890123456789012345678901234567890") == "57edf4a22be3c955ac49da2e2107b67a");
}

TEST_CASE("sha256 pads messages that end at the block edges")
{
	CHECK(sha256(std::string(55, 'a')) == "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318");
	CHECK(sha256(std::string(56, 'a')) == "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a");
	CHECK(sha256(std::string(64, 'a')) == "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb");
}

TEST_CASE("md5 pads messages that end at the block edges")
{
	CHECK(md5(std::string(55, 'a')) == "ef1772b6dff9a122358552954ad0df65");
	CHECK(md5(std::string(56, 'a')) == "3b0c8ac703f828b04c6c197006d17218");
	CHECK(md5(std::string(64, 'a')) == "014842d480b571495a4a0363793f7367");
}

TEST_CASE("chunked updates match a single update across block edges")
{
	const std::string text(200, 'x');
	const auto data = bytes(text);
	constexpr std::array<std::size_t, 9> splits{1, 55, 56, 63, 64, 65, 127, 128, 199};
	for (const auto split : splits)
	{
		CHECK(hash_in_two_parts<rml::hash::Sha256>(data, split) == rml::hash::hash_bytes<rml::hash::Sha256>(data));
		CHECK(hash_in_two_parts<rml::hash::Md5>(data, split) == rml::hash::hash_bytes<rml::hash::Md5>(data));
	}
}
