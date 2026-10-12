#include "api/json.hpp"

namespace rml::api::json
{
	std::string quote(const std::string_view text)
	{
		constexpr std::string_view digits = "0123456789abcdef";
		std::string quoted;
		quoted.reserve(text.size() + 2);
		quoted += '"';
		for (const auto character : text)
		{
			const auto byte = static_cast<unsigned char>(character);
			switch (character)
			{
			case '"': quoted += "\\\""; break;
			case '\\': quoted += "\\\\"; break;
			case '\n': quoted += "\\n"; break;
			case '\r': quoted += "\\r"; break;
			case '\t': quoted += "\\t"; break;
			default:
				if (byte < 0x20)
				{
					quoted += "\\u00";
					quoted += digits[byte >> 4];
					quoted += digits[byte & 0x0F];
				}
				else
					quoted += character;
			}
		}
		quoted += '"';
		return quoted;
	}
}
