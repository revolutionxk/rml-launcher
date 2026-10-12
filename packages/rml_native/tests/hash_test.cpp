#include <doctest/doctest.h>

#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "hash/hash_file.h"
#include "hash/md5.h"
#include "hash/sha256.h"

namespace {

std::span<const std::uint8_t> bytes(std::string_view text) {
  return {reinterpret_cast<const std::uint8_t*>(text.data()), text.size()};
}

std::string sha256(std::string_view text) {
  return rml::hash::hash_bytes(rml::hash::Algorithm::sha256, bytes(text));
}

std::string md5(std::string_view text) {
  return rml::hash::hash_bytes(rml::hash::Algorithm::md5, bytes(text));
}

}

TEST_CASE("sha256 matches the FIPS 180 vectors") {
  CHECK(sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  CHECK(sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  CHECK(sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
  CHECK(sha256(std::string(1000000, 'a')) ==
        "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
}

TEST_CASE("md5 matches the RFC 1321 vectors") {
  CHECK(md5("") == "d41d8cd98f00b204e9800998ecf8427e");
  CHECK(md5("abc") == "900150983cd24fb0d6963f7d28e17f72");
  CHECK(md5("message digest") == "f96b697d7cb7938d525a2f31aaf161d0");
  CHECK(md5("12345678901234567890123456789012345678901234567890123456789012345678901234567890") ==
        "57edf4a22be3c955ac49da2e2107b67a");
}

TEST_CASE("chunked updates match a single update across block edges") {
  const std::string text(200, 'x');
  for (const std::size_t split : std::vector<std::size_t>{1, 55, 56, 63, 64, 65, 127, 128, 199}) {
    rml::hash::Sha256 a;
    a.update(reinterpret_cast<const std::uint8_t*>(text.data()), split);
    a.update(reinterpret_cast<const std::uint8_t*>(text.data()) + split, text.size() - split);
    rml::hash::Sha256 b;
    b.update(reinterpret_cast<const std::uint8_t*>(text.data()), text.size());
    CHECK(a.finish() == b.finish());

    rml::hash::Md5 c;
    c.update(reinterpret_cast<const std::uint8_t*>(text.data()), split);
    c.update(reinterpret_cast<const std::uint8_t*>(text.data()) + split, text.size() - split);
    rml::hash::Md5 d;
    d.update(reinterpret_cast<const std::uint8_t*>(text.data()), text.size());
    CHECK(c.finish() == d.finish());
  }
}
