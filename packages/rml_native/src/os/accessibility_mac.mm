#include "rml/rml.h"

#import <AppKit/AppKit.h>

extern "C" {

int32_t rml_os_reduce_motion(void) {
  @autoreleasepool {
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 1 : 0;
  }
}

}
