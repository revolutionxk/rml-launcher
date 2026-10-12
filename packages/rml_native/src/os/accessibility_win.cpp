#include "rml/rml.h"

#include <windows.h>

extern "C" {

int32_t rml_os_reduce_motion(void) {
  BOOL animations = TRUE;
  if (!SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0)) {
    return -1;
  }
  return animations ? 0 : 1;
}

}
