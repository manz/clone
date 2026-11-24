#ifndef CGHOSTTY_VT_H
#define CGHOSTTY_VT_H

// Umbrella for libghostty-vt. The real headers live in vendor/ghostty/include;
// consumers add `-Xcc -I vendor/ghostty/include` so this angle include resolves,
// and link `-lghostty-vt` from vendor/ghostty/zig-out/lib.
#include <ghostty/vt.h>

#endif
