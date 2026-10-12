#include "exe/bundle_info.hpp"
#include "platform/path.hpp"

#include <CoreFoundation/CoreFoundation.h>
#include <fstream>
#include <iterator>
#include <memory>
#include <string>
#include <type_traits>
#include <vector>

namespace rml::exe
{
	namespace
	{
		struct Releaser
		{
			void operator()(const CFTypeRef object) const noexcept
			{
				CFRelease(object);
			}
		};

		template<typename T>
		using Owned = std::unique_ptr<std::remove_pointer_t<T>, Releaser>;
	}

	[[nodiscard]] static std::string text_of(const CFDictionaryRef dictionary, const CFStringRef key)
	{
		const auto value = CFDictionaryGetValue(dictionary, key);
		if (value == nullptr || CFGetTypeID(value) != CFStringGetTypeID())
			return {};
		const auto string = static_cast<CFStringRef>(value);
		const auto capacity = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8) + 1;
		std::string buffer(static_cast<std::size_t>(capacity), '\0');
		if (!CFStringGetCString(string, buffer.data(), capacity, kCFStringEncodingUTF8))
			return {};
		buffer.resize(std::char_traits<char>::length(buffer.c_str()));
		return buffer;
	}

	std::expected<BundleInfo, Error> bundle_info(const std::filesystem::path& bundle)
	{
		const auto plist = bundle / "Contents" / "Info.plist";
		std::ifstream file(plist, std::ios::binary);
		if (!file)
			return fail("Can't open " + platform::to_utf8(plist));
		const std::vector<char> bytes{std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
		const Owned<CFDataRef> data(
		    CFDataCreate(kCFAllocatorDefault, reinterpret_cast<const UInt8*>(bytes.data()), static_cast<CFIndex>(bytes.size())));
		if (!data)
			return fail("Out of memory");
		const Owned<CFPropertyListRef> list(CFPropertyListCreateWithData(kCFAllocatorDefault, data.get(), kCFPropertyListImmutable, nullptr, nullptr));
		if (!list || CFGetTypeID(list.get()) != CFDictionaryGetTypeID())
			return fail("Damaged Info.plist in " + platform::to_utf8(bundle));
		const auto dictionary = static_cast<CFDictionaryRef>(list.get());
		return BundleInfo{text_of(dictionary, kCFBundleIdentifierKey), text_of(dictionary, CFSTR("CFBundleShortVersionString")), text_of(dictionary, kCFBundleExecutableKey)};
	}
}
