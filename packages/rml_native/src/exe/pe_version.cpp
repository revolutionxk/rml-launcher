#include "exe/pe_version.hpp"

#include "platform/path.hpp"
#include "platform/text.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <optional>
#include <span>
#include <string_view>
#include <utility>
#include <vector>

namespace rml::exe
{
	namespace
	{
		using Bytes = std::vector<std::byte>;

		class PeFile
		{
		public:
			explicit PeFile(const std::filesystem::path& path) :
			    m_stream(path, std::ios::binary)
			{
			}

			[[nodiscard]] bool is_open() const noexcept
			{
				return m_stream.is_open();
			}

			[[nodiscard]] std::optional<Bytes> read(const std::uint64_t offset, const std::size_t size)
			{
				Bytes bytes(size);
				m_stream.clear();
				m_stream.seekg(static_cast<std::streamoff>(offset));
				m_stream.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(size));
				if (static_cast<std::size_t>(m_stream.gcount()) != size)
					return std::nullopt;
				return bytes;
			}

		private:
			std::ifstream m_stream;
		};

		struct Section
		{
			std::uint32_t virtual_address;
			std::uint32_t virtual_size;
			std::uint32_t raw_size;
			std::uint32_t raw_offset;
		};

		struct Image
		{
			std::uint32_t resource_rva;
			std::vector<Section> sections;
		};

		struct Block
		{
			std::size_t end;
			std::uint16_t value_length;
			std::uint16_t type;
			std::u16string key;
			std::size_t value;
			std::size_t children;
		};
	}

	static constexpr std::uint16_t dos_magic = 0x5A4D;
	static constexpr std::uint32_t pe_signature = 0x00004550;
	static constexpr std::uint16_t rt_version = 16;
	static constexpr std::uint32_t subdirectory_flag = 0x80000000;
	static constexpr std::uint32_t fixed_info_signature = 0xFEEF04BD;
	static constexpr std::size_t max_version_size = 1 << 20;

	[[nodiscard]] static std::uint16_t u16(const std::span<const std::byte> data, const std::size_t offset) noexcept
	{
		return static_cast<std::uint16_t>(std::to_integer<std::uint16_t>(data[offset]) | std::to_integer<std::uint16_t>(data[offset + 1]) << 8);
	}

	[[nodiscard]] static std::uint32_t u32(const std::span<const std::byte> data, const std::size_t offset) noexcept
	{
		return static_cast<std::uint32_t>(u16(data, offset)) | static_cast<std::uint32_t>(u16(data, offset + 2)) << 16;
	}

	[[nodiscard]] static constexpr std::size_t align4(const std::size_t offset) noexcept
	{
		return (offset + 3) & ~std::size_t{3};
	}

	[[nodiscard]] static std::optional<std::uint64_t> file_offset(const Image& image, const std::uint32_t rva) noexcept
	{
		for (const auto& section : image.sections)
		{
			const auto extent = std::max(section.virtual_size, section.raw_size);
			if (rva >= section.virtual_address && rva - section.virtual_address < extent)
				return std::uint64_t{section.raw_offset} + (rva - section.virtual_address);
		}
		return std::nullopt;
	}

	[[nodiscard]] static std::expected<Image, Error> read_image(PeFile& file)
	{
		const auto dos = file.read(0, 64);
		if (!dos || u16(*dos, 0) != dos_magic)
			return fail("Not a Windows executable");
		const auto header = u32(*dos, 0x3C);
		const auto nt = file.read(header, 24);
		if (!nt || u32(*nt, 0) != pe_signature)
			return fail("Not a Windows executable");
		const auto section_count = u16(*nt, 6);
		const auto optional_size = u16(*nt, 20);
		const auto optional = file.read(std::uint64_t{header} + 24, optional_size);
		if (!optional || optional_size < 2)
			return fail("Damaged executable header");
		const auto magic = u16(*optional, 0);
		const std::size_t directories = magic == 0x20B ? 112 : magic == 0x10B ? 96 : 0;
		if (directories == 0 || optional_size < directories + 24)
			return fail("Damaged executable header");
		if (u32(*optional, directories - 4) <= 2 || u32(*optional, directories + 16) == 0)
			return fail("The executable has no version resource");
		const auto table = file.read(std::uint64_t{header} + 24 + optional_size, std::size_t{section_count} * 40);
		if (!table)
			return fail("Damaged section table");
		Image image{u32(*optional, directories + 16), {}};
		for (std::size_t index = 0; index < section_count; ++index)
		{
			const auto base = index * 40;
			image.sections.push_back({u32(*table, base + 12), u32(*table, base + 8), u32(*table, base + 16), u32(*table, base + 20)});
		}
		return image;
	}

	[[nodiscard]] static std::optional<std::uint32_t> find_entry(PeFile& file, const std::uint64_t base, const std::uint32_t directory, const std::optional<std::uint16_t> id)
	{
		const auto header = file.read(base + directory, 16);
		if (!header)
			return std::nullopt;
		const auto count = std::size_t{u16(*header, 12)} + u16(*header, 14);
		const auto entries = file.read(base + directory + 16, count * 8);
		if (!entries)
			return std::nullopt;
		for (std::size_t index = 0; index < count; ++index)
		{
			const auto name = u32(*entries, index * 8);
			if (!id || ((name & subdirectory_flag) == 0 && name == *id))
				return u32(*entries, index * 8 + 4);
		}
		return std::nullopt;
	}

	[[nodiscard]] static std::expected<Bytes, Error> read_version_resource(PeFile& file, const Image& image)
	{
		const auto base = file_offset(image, image.resource_rva);
		if (!base)
			return fail("Damaged resource section");
		const auto type = find_entry(file, *base, 0, rt_version);
		if (!type || (*type & subdirectory_flag) == 0)
			return fail("The executable has no version resource");
		const auto name = find_entry(file, *base, *type & ~subdirectory_flag, std::nullopt);
		if (!name || (*name & subdirectory_flag) == 0)
			return fail("Damaged version resource");
		const auto language = find_entry(file, *base, *name & ~subdirectory_flag, std::nullopt);
		if (!language || (*language & subdirectory_flag) != 0)
			return fail("Damaged version resource");
		const auto entry = file.read(*base + *language, 16);
		if (!entry)
			return fail("Damaged version resource");
		const auto data = file_offset(image, u32(*entry, 0));
		const auto size = u32(*entry, 4);
		if (!data || size == 0 || size > max_version_size)
			return fail("Damaged version resource");
		auto bytes = file.read(*data, size);
		if (!bytes)
			return fail("Damaged version resource");
		return std::move(*bytes);
	}

	[[nodiscard]] static std::optional<Block> read_block(const std::span<const std::byte> data, const std::size_t offset)
	{
		if (offset + 6 > data.size())
			return std::nullopt;
		const std::size_t length = u16(data, offset);
		const auto end = offset + length;
		if (length < 6 || end > data.size())
			return std::nullopt;
		Block block{end, u16(data, offset + 2), u16(data, offset + 4), {}, 0, 0};
		auto cursor = offset + 6;
		for (; cursor + 1 < end; cursor += 2)
		{
			const auto unit = u16(data, cursor);
			if (unit == 0)
				break;
			block.key += static_cast<char16_t>(unit);
		}
		block.value = std::min(align4(cursor + 2), end);
		const std::size_t value_bytes = block.type == 1 ? std::size_t{block.value_length} * 2 : block.value_length;
		block.children = std::min(align4(block.value + value_bytes), end);
		return block;
	}

	template<typename Visit>
	static void for_each_child(const std::span<const std::byte> data, const Block& parent, Visit&& visit)
	{
		auto offset = parent.children;
		while (offset < parent.end)
		{
			const auto child = read_block(data, offset);
			if (!child || visit(*child))
				return;
			offset = align4(child->end);
		}
	}

	[[nodiscard]] static std::string read_text(const std::span<const std::byte> data, const Block& block)
	{
		std::u16string text;
		for (auto cursor = block.value; cursor + 1 < block.end; cursor += 2)
		{
			const auto unit = u16(data, cursor);
			if (unit == 0)
				break;
			text += static_cast<char16_t>(unit);
		}
		return platform::utf16_to_utf8(text);
	}

	[[nodiscard]] static std::optional<std::string> string_file_version(const std::span<const std::byte> data, const Block& root)
	{
		std::optional<std::string> version;
		const auto found = [&] {
			return version.has_value();
		};
		for_each_child(data, root, [&](const Block& info) {
			if (info.key == u"StringFileInfo")
			{
				for_each_child(data, info, [&](const Block& table) {
					for_each_child(data, table, [&](const Block& entry) {
						if (entry.key == u"FileVersion")
						{
							if (auto text = read_text(data, entry); !text.empty())
								version = std::move(text);
						}
						return found();
					});
					return found();
				});
			}
			return found();
		});
		return version;
	}

	[[nodiscard]] static std::optional<std::string> fixed_file_version(const std::span<const std::byte> data, const Block& root)
	{
		if (root.value_length < 52 || root.value + 52 > root.end || u32(data, root.value) != fixed_info_signature)
			return std::nullopt;
		const auto high = u32(data, root.value + 8);
		const auto low = u32(data, root.value + 12);
		return std::to_string(high >> 16) + "." + std::to_string(high & 0xFFFF) + "." + std::to_string(low >> 16) + "." + std::to_string(low & 0xFFFF);
	}

	std::expected<std::string, Error> file_version(const std::filesystem::path& path)
	{
		PeFile file(path);
		if (!file.is_open())
			return fail("Can't open " + platform::to_utf8(path));
		const auto image = read_image(file);
		if (!image)
			return std::unexpected(image.error());
		const auto data = read_version_resource(file, *image);
		if (!data)
			return std::unexpected(data.error());
		const auto root = read_block(*data, 0);
		if (!root || root->key != u"VS_VERSION_INFO")
			return fail("Damaged version resource");
		if (auto version = string_file_version(*data, *root))
			return std::move(*version);
		if (auto version = fixed_file_version(*data, *root))
			return std::move(*version);
		return fail("The executable has no file version");
	}
}
