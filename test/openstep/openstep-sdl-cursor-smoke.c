/* Standard SDL2 cursor and window-local mouse-warp smoke for OPENSTEP.
   Run this from a Workspace console; no private OpenStep API is used here. */
#include <stdio.h>

#include "SDL.h"

static int
fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-cursor-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

int
main(int argc, char **argv)
{
    static const Uint8 cursor_data[8] = {
        0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff
    };
    static const Uint8 cursor_mask[8] = {
        0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff, 0xff
    };
    SDL_Window *window;
    SDL_Surface *surface;
    SDL_Cursor *bitmap_cursor;
    SDL_Cursor *colour_cursor;
    SDL_Cursor *arrow_cursor;
    SDL_Cursor *ibeam_cursor;
    int x, y, global_x, global_y;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL OpenStep cursor smoke", 40, 40, 96, 72, 0);
    if (!window) {
        SDL_Quit();
        return fail("window creation failed");
    }
    SDL_SetWindowInputFocus(window);
    SDL_PumpEvents();
    if (SDL_GetMouseFocus() != window) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("window did not receive mouse focus");
    }

    bitmap_cursor = SDL_CreateCursor(cursor_data, cursor_mask, 8, 8, 0, 0);
    if (!bitmap_cursor) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_CreateCursor failed");
    }
    surface = SDL_CreateRGBSurfaceWithFormat(0, 16, 16, 32, SDL_PIXELFORMAT_ARGB8888);
    if (!surface) {
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("cursor surface creation failed");
    }
    SDL_FillRect(surface, NULL, SDL_MapRGBA(surface->format, 0x20, 0x80, 0xe0, 0xff));
    colour_cursor = SDL_CreateColorCursor(surface, 7, 7);
    SDL_FreeSurface(surface);
    if (!colour_cursor) {
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_CreateColorCursor failed");
    }
    arrow_cursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);
    ibeam_cursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_IBEAM);
    if (!arrow_cursor || !ibeam_cursor) {
        if (ibeam_cursor) SDL_FreeCursor(ibeam_cursor);
        if (arrow_cursor) SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("native SDL_CreateSystemCursor failed");
    }

    SDL_SetCursor(bitmap_cursor);
    SDL_SetCursor(colour_cursor);
    if (SDL_GetCursor() != colour_cursor) {
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_SetCursor did not retain the colour cursor");
    }
    SDL_SetCursor(arrow_cursor);
    SDL_SetCursor(ibeam_cursor);
    if (SDL_GetCursor() != ibeam_cursor) {
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_SetCursor did not retain the I-beam cursor");
    }
    if (SDL_ShowCursor(SDL_DISABLE) != SDL_ENABLE || SDL_ShowCursor(SDL_QUERY) != SDL_DISABLE ||
        SDL_ShowCursor(SDL_ENABLE) != SDL_DISABLE || SDL_ShowCursor(SDL_QUERY) != SDL_ENABLE) {
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_ShowCursor visibility transition failed");
    }
    /* The SDL2 core deliberately falls back to our verified local warp when
       OPENSTEP has no separate physical relative-mouse facility. */
    if (SDL_SetRelativeMouseMode(SDL_TRUE) < 0 || !SDL_GetRelativeMouseMode() ||
        SDL_SetRelativeMouseMode(SDL_FALSE) < 0 || SDL_GetRelativeMouseMode()) {
        SDL_SetRelativeMouseMode(SDL_FALSE);
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("relative mouse warp fallback failed");
    }
    SDL_ClearError();
    if (SDL_CaptureMouse(SDL_TRUE) >= 0 || SDL_GetError()[0] == '\0') {
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_CaptureMouse did not report unavailable native capture");
    }
    SDL_ClearError();
    if (SDL_WarpMouseGlobal(20, 15) >= 0 || SDL_GetError()[0] == '\0') {
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_WarpMouseGlobal did not report unavailable global coordinates");
    }
    SDL_ClearError();

    SDL_WarpMouseInWindow(window, 20, 15);
    SDL_PumpEvents();
    SDL_GetMouseState(&x, &y);
    if (x != 20 || y != 15) {
        fprintf(stderr, "openstep-sdl-cursor-smoke: warp state is %d,%d, expected 20,15\n", x, y);
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_GetGlobalMouseState(&global_x, &global_y);
    if (global_x != 60 || global_y != 55) {
        fprintf(stderr, "openstep-sdl-cursor-smoke: global state is %d,%d, expected 60,55\n",
                global_x, global_y);
        SDL_SetCursor(SDL_GetDefaultCursor());
        SDL_FreeCursor(ibeam_cursor);
        SDL_FreeCursor(arrow_cursor);
        SDL_FreeCursor(colour_cursor);
        SDL_FreeCursor(bitmap_cursor);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_SetCursor(SDL_GetDefaultCursor());
    SDL_FreeCursor(ibeam_cursor);
    SDL_FreeCursor(arrow_cursor);
    SDL_FreeCursor(colour_cursor);
    SDL_FreeCursor(bitmap_cursor);
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-cursor-smoke: PASS bitmap+colour+system+visibility+relative+capture+global-state+warp\n");
    return 0;
}
