#include "platform/text.hpp"

namespace rml::platform
{
	static void append_code_point(std::string& out, const char32_t code)
	{
		if (code < 0x80)
			out += static_cast<char>(code);
		else if (code < 0x800)
		{
			out += static_cast<char>(0xC0 | (code >> 6));
			out += static_cast<char>(0x80 | (code & 0x3F));
		}
		else if (code < 0x10000)
		{
			out += static_cast<char>(0xE0 | (code >> 12));
			out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
			out += static_cast<char>(0x80 | (code & 0x3F));
		}
		else
		{
			out += static_cast<char>(0xF0 | (code >> 18));
			out += static_cast<char>(0x80 | ((code >> 12) & 0x3F));
			out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
			out += static_cast<char>(0x80 | (code & 0x3F));
		}
	}

	[[nodiscard]] static constexpr bool is_high_surrogate(const char32_t unit) noexcept
	{
		return unit >= 0xD800 && unit <= 0xDBFF;
	}

	[[nodiscard]] static constexpr bool is_low_surrogate(const char32_t unit) noexcept
	{
		return unit >= 0xDC00 && unit <= 0xDFFF;
	}

	std::string utf16_to_utf8(const std::u16string_view text)
	{
		std::string out;
		out.reserve(text.size());
		for (std::size_t index = 0; index < text.size(); ++index)
		{
			char32_t code = text[index];
			if (is_high_surrogate(code) && index + 1 < text.size() && is_low_surrogate(text[index + 1]))
				code = 0x10000 + ((code - 0xD800) << 10) + (text[++index] - 0xDC00);
			else if (is_high_surrogate(code) || is_low_surrogate(code))
				code = 0xFFFD;
			append_code_point(out, code);
		}
		return out;
	}
}
