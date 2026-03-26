#ifndef ghostty_helpers_h
#define ghostty_helpers_h

#include <ghostty/vt.h>

static inline GhosttyRenderStateColors ghostty_init_render_state_colors(void) {
    GhosttyRenderStateColors c = {0};
    c.size = sizeof(GhosttyRenderStateColors);
    return c;
}

static inline GhosttyStyle ghostty_init_style(void) {
    GhosttyStyle s = {0};
    s.size = sizeof(GhosttyStyle);
    return s;
}

#endif /* ghostty_helpers_h */
