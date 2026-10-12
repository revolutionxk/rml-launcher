#pragma once

#include "hash/block_hash.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>

namespace rml::hash
{
	struct Sha256Rounds
	{
		using State = std::array<std::uint32_t, 8>;

		static constexpr auto byte_order = std::endian::big;

		static constexpr State initial_state{0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

		[[nodiscard]] static constexpr State apply(State state, const Block& block) noexcept
		{
			std::array<std::uint32_t, 64> schedule{};
			std::ranges::copy(block, schedule.begin());
			for (std::size_t i = block.size(); i < schedule.size(); ++i)
			{
				const auto s0 = std::rotr(schedule[i - 15], 7) ^ std::rotr(schedule[i - 15], 18) ^ (schedule[i - 15] >> 3);
				const auto s1 = std::rotr(schedule[i - 2], 17) ^ std::rotr(schedule[i - 2], 19) ^ (schedule[i - 2] >> 10);
				schedule[i] = schedule[i - 16] + s0 + schedule[i - 7] + s1;
			}

			auto& [a, b, c, d, e, f, g, h] = state;
			for (std::size_t i = 0; i < schedule.size(); ++i)
			{
				const auto s1 = std::rotr(e, 6) ^ std::rotr(e, 11) ^ std::rotr(e, 25);
				const auto choice = (e & f) ^ (~e & g);
				const auto t1 = h + s1 + choice + round_constants[i] + schedule[i];
				const auto s0 = std::rotr(a, 2) ^ std::rotr(a, 13) ^ std::rotr(a, 22);
				const auto majority = (a & b) ^ (a & c) ^ (b & c);
				const auto t2 = s0 + majority;
				h = g;
				g = f;
				f = e;
				e = d + t1;
				d = c;
				c = b;
				b = a;
				a = t1 + t2;
			}
			return state;
		}

		static constexpr std::array<std::uint32_t, 64> round_constants{
		    0x428a2f98,
		    0x71374491,
		    0xb5c0fbcf,
		    0xe9b5dba5,
		    0x3956c25b,
		    0x59f111f1,
		    0x923f82a4,
		    0xab1c5ed5,
		    0xd807aa98,
		    0x12835b01,
		    0x243185be,
		    0x550c7dc3,
		    0x72be5d74,
		    0x80deb1fe,
		    0x9bdc06a7,
		    0xc19bf174,
		    0xe49b69c1,
		    0xefbe4786,
		    0x0fc19dc6,
		    0x240ca1cc,
		    0x2de92c6f,
		    0x4a7484aa,
		    0x5cb0a9dc,
		    0x76f988da,
		    0x983e5152,
		    0xa831c66d,
		    0xb00327c8,
		    0xbf597fc7,
		    0xc6e00bf3,
		    0xd5a79147,
		    0x06ca6351,
		    0x14292967,
		    0x27b70a85,
		    0x2e1b2138,
		    0x4d2c6dfc,
		    0x53380d13,
		    0x650a7354,
		    0x766a0abb,
		    0x81c2c92e,
		    0x92722c85,
		    0xa2bfe8a1,
		    0xa81a664b,
		    0xc24b8b70,
		    0xc76c51a3,
		    0xd192e819,
		    0xd6990624,
		    0xf40e3585,
		    0x106aa070,
		    0x19a4c116,
		    0x1e376c08,
		    0x2748774c,
		    0x34b0bcb5,
		    0x391c0cb3,
		    0x4ed8aa4a,
		    0x5b9cca4f,
		    0x682e6ff3,
		    0x748f82ee,
		    0x78a5636f,
		    0x84c87814,
		    0x8cc70208,
		    0x90befffa,
		    0xa4506ceb,
		    0xbef9a3f7,
		    0xc67178f2,
		};
	};

	using Sha256 = BlockHash<Sha256Rounds>;
}
