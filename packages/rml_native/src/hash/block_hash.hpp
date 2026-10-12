#pragma once

#include <algorithm>
#include <array>
#include <bit>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <span>

namespace rml::hash
{
	inline constexpr std::size_t block_size = 64;

	using Block = std::array<std::uint32_t, block_size / sizeof(std::uint32_t)>;

	template<std::endian Order, std::unsigned_integral T>
	[[nodiscard]] constexpr T in_byte_order(const T value) noexcept
	{
		return Order == std::endian::native ? value : std::byteswap(value);
	}

	template<std::endian Order, std::unsigned_integral T, std::size_t N>
	[[nodiscard]] constexpr std::array<T, N> in_byte_order(std::array<T, N> values) noexcept
	{
		for (auto& value : values)
			value = in_byte_order<Order>(value);
		return values;
	}

	template<typename Rounds>
	class BlockHash
	{
	public:
		using State = typename Rounds::State;
		using Digest = std::array<std::byte, sizeof(State)>;

		constexpr void update(std::span<const std::byte> data) noexcept
		{
			m_length += data.size();
			while (!data.empty())
			{
				const auto space = std::span(m_buffer).subspan(m_buffered);
				const auto take = std::min(data.size(), space.size());
				std::ranges::copy(data.first(take), space.begin());
				data = data.subspan(take);
				m_buffered += take;
				if (m_buffered == block_size)
				{
					compress();
					m_buffered = 0;
				}
			}
		}

		[[nodiscard]] constexpr Digest finish() noexcept
		{
			const auto bit_length = std::bit_cast<std::array<std::byte, sizeof(m_length)>>(in_byte_order<byte_order>(m_length * 8));
			update(std::array{std::byte{0x80}});
			update(std::span(zeros).first((block_size + length_offset - m_buffered) % block_size));
			update(bit_length);
			return std::bit_cast<Digest>(in_byte_order<byte_order>(m_state));
		}

	private:
		static constexpr auto byte_order = Rounds::byte_order;
		static constexpr std::size_t length_offset = block_size - sizeof(std::uint64_t);
		static constexpr std::array<std::byte, block_size> zeros{};

		constexpr void compress() noexcept
		{
			const auto mixed = Rounds::apply(m_state, in_byte_order<byte_order>(std::bit_cast<Block>(m_buffer)));
			std::ranges::transform(m_state, mixed, m_state.begin(), std::plus{});
		}

		State m_state = Rounds::initial_state;
		std::array<std::byte, block_size> m_buffer{};
		std::size_t m_buffered = 0;
		std::uint64_t m_length = 0;
	};
}
