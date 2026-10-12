#include "zip/extract.hpp"

#include "platform/path.hpp"
#include "zip/entry_path.hpp"

#include <fstream>
#include <miniz.h>
#include <set>
#include <system_error>
#include <utility>

namespace rml::zip
{
	namespace
	{
		struct Entry
		{
			mz_uint index;
			std::string path;
			std::uint64_t size;
			std::uint32_t mode;
			bool directory;
			bool symlink;
			std::string link;
		};

		class Reader
		{
		public:
			Reader() noexcept
			{
				mz_zip_zero_struct(&m_zip);
			}

			Reader(const Reader&) = delete;
			Reader& operator=(const Reader&) = delete;

			~Reader()
			{
				if (m_open)
					mz_zip_reader_end(&m_zip);
			}

			[[nodiscard]] std::expected<void, Error> open(const std::filesystem::path& path)
			{
				std::error_code ec;
				const auto size = std::filesystem::file_size(path, ec);
				m_stream.open(path, std::ios::binary);
				if (ec || !m_stream)
					return fail("Can't open " + platform::to_utf8(path));
				m_zip.m_pRead = &Reader::read;
				m_zip.m_pIO_opaque = this;
				if (!mz_zip_reader_init(&m_zip, size, 0))
					return fail("Not a zip archive: " + platform::to_utf8(path) + " (" + last_error() + ")");
				m_open = true;
				return {};
			}

			[[nodiscard]] mz_zip_archive* get() noexcept
			{
				return &m_zip;
			}

			[[nodiscard]] std::string last_error()
			{
				return mz_zip_get_error_string(mz_zip_get_last_error(&m_zip));
			}

		private:
			static std::size_t read(void* opaque, const mz_uint64 offset, void* buffer, const std::size_t size)
			{
				auto& stream = static_cast<Reader*>(opaque)->m_stream;
				stream.clear();
				stream.seekg(static_cast<std::streamoff>(offset));
				stream.read(static_cast<char*>(buffer), static_cast<std::streamsize>(size));
				return static_cast<std::size_t>(stream.gcount());
			}

			mz_zip_archive m_zip{};
			std::ifstream m_stream;
			bool m_open = false;
		};

		class Tracker
		{
		public:
			Tracker(const Progress& progress, const std::uint64_t total) :
			    m_progress(progress),
			    m_total(total)
			{
			}

			void advance(const std::uint64_t bytes)
			{
				m_done += bytes;
				if (m_done - m_reported >= step)
					report();
			}

			void report()
			{
				m_reported = m_done;
				if (m_progress)
					m_progress(m_done, m_total);
			}

		private:
			static constexpr std::uint64_t step = std::uint64_t{4} << 20;

			const Progress& m_progress;
			std::uint64_t m_total;
			std::uint64_t m_done = 0;
			std::uint64_t m_reported = 0;
		};

		struct Sink
		{
			std::ofstream& stream;
			Tracker& tracker;
			std::uint64_t written = 0;
		};
	}

	static constexpr std::uint32_t file_type_mask = 0170000;
	static constexpr std::uint32_t symlink_type = 0120000;

	[[nodiscard]] static std::string entry_name(mz_zip_archive* zip, const mz_uint index)
	{
		const auto size = mz_zip_reader_get_filename(zip, index, nullptr, 0);
		std::string name(size, '\0');
		mz_zip_reader_get_filename(zip, index, name.data(), size);
		name.resize(size > 0 ? size - 1 : 0);
		return name;
	}

	static std::size_t append_chunk(void* opaque, const mz_uint64, const void* buffer, const std::size_t size)
	{
		static_cast<std::string*>(opaque)->append(static_cast<const char*>(buffer), size);
		return size;
	}

	[[nodiscard]] static bool escapes(const std::filesystem::path& root, const std::filesystem::path& candidate)
	{
		const auto relative = candidate.lexically_normal().lexically_relative(root.lexically_normal());
		return relative.empty() || *relative.begin() == "..";
	}

	static constexpr std::uint64_t max_link_size = 4096;

	[[nodiscard]] static bool inside(const std::filesystem::path& root, const std::filesystem::path& candidate)
	{
		std::error_code ec;
		const auto resolved = std::filesystem::weakly_canonical(candidate, ec);
		return !ec && !escapes(root, resolved);
	}

	[[nodiscard]] static bool safe_link_text(const std::string& link, const std::filesystem::path& folder)
	{
		if (link.empty() || link.contains('\0') || link.contains(':'))
			return false;
		const auto link_target = platform::path_from_utf8(link);
		return !link_target.is_absolute() && !link.starts_with('/') && !escapes(".", (folder / link_target).lexically_normal());
	}

	[[nodiscard]] static std::expected<std::string, Error> read_link(Reader& reader, const mz_uint index, const std::string& name)
	{
		std::string link;
		if (!mz_zip_reader_extract_to_callback(reader.get(), index, &append_chunk, &link, 0))
			return fail("Can't extract " + name + ": " + reader.last_error());
		return link;
	}

	[[nodiscard]] static std::expected<std::vector<Entry>, Error> list_entries(Reader& reader)
	{
		auto* const zip = reader.get();
		const auto count = mz_zip_reader_get_num_files(zip);
		std::vector<Entry> entries;
		std::set<std::string> links;
		entries.reserve(count);
		for (mz_uint index = 0; index < count; ++index)
		{
			mz_zip_archive_file_stat stat{};
			if (!mz_zip_reader_file_stat(zip, index, &stat))
				return fail("Damaged zip entry " + std::to_string(index) + " (" + reader.last_error() + ")");
			const auto name = entry_name(zip, index);
			if (stat.m_is_encrypted || !stat.m_is_supported)
				return fail("Unsupported zip entry: " + name);
			auto path = safe_entry_path(name);
			if (!path)
				return fail("Unsafe path in archive: " + name);
			if (path->empty())
				continue;
			const auto mode = stat.m_external_attr >> 16;
			const bool directory = stat.m_is_directory || name.ends_with('/') || name.ends_with('\\');
#if defined(_WIN32)
			const bool symlink = false;
#else
			const bool symlink = !directory && (mode & file_type_mask) == symlink_type;
#endif
			for (auto cut = path->find('/'); cut != std::string::npos; cut = path->find('/', cut + 1))
			{
				if (links.contains(path->substr(0, cut)))
					return fail("Unsafe path in archive: " + name);
			}
			std::string link;
			if (symlink)
			{
				if (stat.m_uncomp_size > max_link_size)
					return fail("Unsafe link in archive: " + *path);
				auto text = read_link(reader, index, *path);
				if (!text)
					return std::unexpected(text.error());
				link = std::move(*text);
				if (!safe_link_text(link, std::filesystem::path(platform::path_from_utf8(*path)).parent_path()))
					return fail("Unsafe link in archive: " + *path);
				links.insert(*path);
			}
			entries.push_back({index, std::move(*path), stat.m_uncomp_size, mode, directory, symlink, std::move(link)});
		}
		return entries;
	}

	static std::size_t write_chunk(void* opaque, const mz_uint64, const void* buffer, const std::size_t size)
	{
		auto& sink = *static_cast<Sink*>(opaque);
		sink.stream.write(static_cast<const char*>(buffer), static_cast<std::streamsize>(size));
		if (!sink.stream)
			return 0;
		sink.written += size;
		sink.tracker.advance(size);
		return size;
	}

	[[nodiscard]] static std::expected<std::uint64_t, Error> write_file(Reader& reader, const Entry& entry, const std::filesystem::path& target, Tracker& tracker)
	{
		std::error_code ec;
		if (std::filesystem::is_symlink(target, ec))
			std::filesystem::remove(target, ec);
		std::ofstream stream(target, std::ios::binary | std::ios::trunc);
		if (!stream)
			return fail("Can't write " + platform::to_utf8(target));
		Sink sink{stream, tracker};
		if (!mz_zip_reader_extract_to_callback(reader.get(), entry.index, &write_chunk, &sink, 0))
			return fail("Can't extract " + entry.path + ": " + reader.last_error());
		stream.close();
		if (!stream)
			return fail("Can't write " + platform::to_utf8(target));
		if (sink.written != entry.size)
			return fail("Size mismatch for " + entry.path);
#if !defined(_WIN32)
		if ((entry.mode & 0777) != 0)
		{
			std::filesystem::permissions(target, static_cast<std::filesystem::perms>(entry.mode & 0777), ec);
			if (ec)
				return fail("Can't set permissions on " + entry.path + ": " + ec.message());
		}
#endif
		return sink.written;
	}

	[[nodiscard]] static std::expected<void, Error> make_symlink(const Entry& entry, const std::filesystem::path& target)
	{
		std::error_code ec;
		std::filesystem::remove(target, ec);
		std::filesystem::create_symlink(platform::path_from_utf8(entry.link), target, ec);
		if (ec)
			return fail("Can't create link " + entry.path + ": " + ec.message());
		return {};
	}

	std::expected<Extraction, Error> extract(const std::filesystem::path& archive, const std::filesystem::path& destination, const Progress& progress)
	{
		Reader reader;
		if (auto opened = reader.open(archive); !opened)
			return std::unexpected(opened.error());
		const auto entries = list_entries(reader);
		if (!entries)
			return std::unexpected(entries.error());
		std::uint64_t total = 0;
		for (const auto& entry : *entries)
		{
			if (!entry.directory)
				total += entry.size;
		}
		std::error_code ec;
		std::filesystem::create_directories(destination, ec);
		if (ec)
			return fail("Can't create " + platform::to_utf8(destination));
		const auto root = std::filesystem::canonical(destination, ec);
		if (ec)
			return fail("Can't resolve " + platform::to_utf8(destination));
		Tracker tracker(progress, total);
		Extraction extraction;
		std::vector<const Entry*> links;
		for (const auto& entry : *entries)
		{
			const auto target = destination / platform::path_from_utf8(entry.path);
			if (!inside(root, entry.directory ? target : target.parent_path()))
				return fail("Unsafe path in archive: " + entry.path);
			std::filesystem::create_directories(entry.directory ? target : target.parent_path(), ec);
			if (ec)
				return fail("Can't create the folder for " + entry.path);
			if (entry.directory)
				continue;
			if (entry.symlink)
			{
				if (auto linked = make_symlink(entry, target); !linked)
					return std::unexpected(linked.error());
				links.push_back(&entry);
				tracker.advance(entry.size);
				continue;
			}
			const auto written = write_file(reader, entry, target, tracker);
			if (!written)
				return std::unexpected(written.error());
			extraction.files.push_back({entry.path, *written});
			extraction.bytes += *written;
		}
		for (const auto* link : links)
		{
			const auto folder = (destination / platform::path_from_utf8(link->path)).parent_path();
			if (!inside(root, folder / platform::path_from_utf8(link->link)))
				return fail("Unsafe link in archive: " + link->path);
		}
		tracker.report();
		return extraction;
	}
}
