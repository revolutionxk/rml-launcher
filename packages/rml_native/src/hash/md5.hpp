#pragma once

#include "hash/block_hash.hpp"

#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <utility>

namespace rml::hash
{
	struct Md5Rounds
	{
		using State = std::array<std::uint32_t, 4>;

		static constexpr auto byte_order = std::endian::little;

		static constexpr State initial_state{0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476};

		[[nodiscard]] static constexpr std::pair<std::uint32_t, std::size_t> auxiliary(const std::size_t i, const std::uint32_t b, const std::uint32_t c, const std::uint32_t d) noexcept
		{
			switch (i / 16)
			{
			case 0: return {(b & c) | (~b & d), i};
			case 1: return {(d & b) | (~d & c), (5 * i + 1) % 16};
			case 2: return {b ^ c ^ d, (3 * i + 5) % 16};
			default: return {c ^ (b | ~d), 7 * i % 16};
			}
		}

		[[nodiscard]] static constexpr State apply(State state, const Block& block) noexcept
		{
			auto& [a, b, c, d] = state;
			for (std::size_t i = 0; i < round_constants.size(); ++i)
			{
				const auto [mixed, word] = auxiliary(i, b, c, d);
				const auto rotated = std::rotl(a + mixed + round_constants[i] + block[word], shifts[i / 16][i % 4]);
				a = d;
				d = c;
				c = b;
				b += rotated;
			}
			return state;
		}

		static constexpr std::array<std::uint32_t, 64> round_constants{
		    0xd76aa478,
		    0xe8c7b756,
		    0x242070db,
		    0xc1bdceee,
		    0xf57c0faf,
		    0x4787c62a,
		    0xa8304613,
		    0xfd469501,
		    0x698098d8,
		    0x8b44f7af,
		    0xffff5bb1,
		    0x895cd7be,
		    0x6b901122,
		    0xfd987193,
		    0xa679438e,
		    0x49b40821,
		    0xf61e2562,
		    0xc040b340,
		    0x265e5a51,
		    0xe9b6c7aa,
		    0xd62f105d,
		    0x02441453,
		    0xd8a1e681,
		    0xe7d3fbc8,
		    0x21e1cde6,
		    0xc33707d6,
		    0xf4d50d87,
		    0x455a14ed,
		    0xa9e3e905,
		    0xfcefa3f8,
		    0x676f02d9,
		    0x8d2a4c8a,
		    0xfffa3942,
		    0x8771f681,
		    0x6d9d6122,
		    0xfde5380c,
		    0xa4beea44,
		    0x4bdecfa9,
		    0xf6bb4b60,
		    0xbebfbc70,
		    0x289b7ec6,
		    0xeaa127fa,
		    0xd4ef3085,
		    0x04881d05,
		    0xd9d4d039,
		    0xe6db99e5,
		    0x1fa27cf8,
		    0xc4ac5665,
		    0xf4292244,
		    0x432aff97,
		    0xab9423a7,
		    0xfc93a039,
		    0x655b59c3,
		    0x8f0ccc92,
		    0xffeff47d,
		    0x85845dd1,
		    0x6fa87e4f,
		    0xfe2ce6e0,
		    0xa3014314,
		    0x4e0811a1,
		    0xf7537e82,
		    0xbd3af235,
		    0x2ad7d2bb,
		    0xeb86d391,
		};

		static constexpr std::array<std::array<int, 4>, 4> shifts{{
		    {7, 12, 17, 22},
		    {5, 9, 14, 20},
		    {4, 11, 16, 23},
		    {6, 10, 15, 21},
		}};
	};

	using Md5 = BlockHash<Md5Rounds>;
}
