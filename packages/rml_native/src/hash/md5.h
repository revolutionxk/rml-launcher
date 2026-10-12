#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace rml::hash {

class Md5 {
 public:
  static constexpr std::size_t digest_size = 16;

  Md5();

  void update(const std::uint8_t* data, std::size_t size);

  std::array<std::uint8_t, digest_size> finish();

 private:
  void compress(const std::uint8_t* block);

  std::array<std::uint32_t, 4> state_;
  std::array<std::uint8_t, 64> buffer_{};
  std::size_t buffered_ = 0;
  std::uint64_t total_ = 0;
};

}
