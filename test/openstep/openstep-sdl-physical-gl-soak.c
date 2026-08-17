/* One-minute visible SDL2/Mesa swap soak through GCD and final libSDL2.a. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_opengl.h"

#define FRAME_COUNT 120
#define FRAME_MILLISECONDS 500

typedef void (APIENTRY *ClearColorProc)(GLclampf red, GLclampf green,
                                        GLclampf blue, GLclampf alpha);
typedef void (APIENTRY *ClearProc)(GLbitfield mask);

static const float colors[][3] = {
    { 0.75f, 0.08f, 0.08f },
    { 0.08f, 0.15f, 0.75f },
    { 0.08f, 0.65f, 0.20f },
    { 0.65f, 0.42f, 0.08f }
};

static int Fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-physical-gl-soak: %s: %s\n", what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(void)
{
    SDL_Window *window = NULL;
    SDL_GLContext context = NULL;
    ClearColorProc clear_color;
    ClearProc clear;
    int frame;
    int result = 0;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-physical-gl-soak.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return Fail("video init failed");
    window = SDL_CreateWindow("SDL2 Mesa OpenGL 60-second soak",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              480, 240, SDL_WINDOW_OPENGL);
    if (window == NULL) {
        result = Fail("window creation failed");
        goto done;
    }
    context = SDL_GL_CreateContext(window);
    if (context == NULL) {
        result = Fail("context creation failed");
        goto done;
    }
    clear_color = (ClearColorProc)SDL_GL_GetProcAddress("glClearColor");
    clear = (ClearProc)SDL_GL_GetProcAddress("glClear");
    if (clear_color == NULL || clear == NULL) {
        result = Fail("GL entry point lookup failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-gl-soak: START frames=%d duration=%dms\n",
            FRAME_COUNT, FRAME_COUNT * FRAME_MILLISECONDS);
    fflush(stdout);
    for (frame = 0; frame < FRAME_COUNT; ++frame) {
        const float *color = colors[frame % SDL_arraysize(colors)];
        Uint32 deadline;

        clear_color(color[0], color[1], color[2], 1.0f);
        clear(GL_COLOR_BUFFER_BIT);
        SDL_ClearError();
        SDL_GL_SwapWindow(window);
        if (*SDL_GetError()) {
            result = Fail("SDL_GL_SwapWindow failed");
            goto done;
        }
        deadline = SDL_GetTicks() + FRAME_MILLISECONDS;
        while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
            SDL_PumpEvents();
            SDL_Delay(10);
        }
    }

done:
    if (context != NULL) SDL_GL_DeleteContext(context);
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-physical-gl-soak: PASS swaps=%d\n", FRAME_COUNT);
    }
    fflush(stdout);
    return result;
}
