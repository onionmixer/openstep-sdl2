/* Standard SDL2 OpenGL smoke for the OPENSTEP Mesa 3.4.2 backend.
   The link gate is WindowServer-independent; execution needs an AppKit/DPS
   session and is intentionally performed separately. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_opengl.h"

typedef const GLubyte *(APIENTRY *GetStringProc)(GLenum name);
typedef void (APIENTRY *ClearColorProc)(GLclampf red, GLclampf green,
                                        GLclampf blue, GLclampf alpha);
typedef void (APIENTRY *ClearProc)(GLbitfield mask);

static void
checkpoint(const char *name)
{
    fprintf(stderr, "openstep-sdl-gl-window-smoke: %s\n", name);
    fflush(stderr);
}

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_GLContext context;
    GetStringProc get_string;
    ClearColorProc clear_color;
    ClearProc clear;
    int width;
    int height;

    (void)argc;
    (void)argv;
    checkpoint("SDL_Init(SDL_INIT_VIDEO)");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init video failed: %s\n", SDL_GetError());
        return 1;
    }
    checkpoint("SDL_CreateWindow(SDL_WINDOW_OPENGL)");
    window = SDL_CreateWindow("SDL OpenStep GL smoke", SDL_WINDOWPOS_UNDEFINED,
                              SDL_WINDOWPOS_UNDEFINED, 64, 48,
                              SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN);
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    checkpoint("SDL_GL_CreateContext");
    context = SDL_GL_CreateContext(window);
    if (!context) {
        fprintf(stderr, "SDL_GL_CreateContext failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    checkpoint("SDL_GL_GetProcAddress");
    get_string = (GetStringProc)SDL_GL_GetProcAddress("glGetString");
    clear_color = (ClearColorProc)SDL_GL_GetProcAddress("glClearColor");
    clear = (ClearProc)SDL_GL_GetProcAddress("glClear");
    if (!get_string || !clear_color || !clear || !get_string(GL_VERSION)) {
        fprintf(stderr, "SDL_GL_GetProcAddress failed: %s\n", SDL_GetError());
        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    checkpoint("drawable size and swap interval");
    SDL_GL_GetDrawableSize(window, &width, &height);
    if (width != 64 || height != 48 || SDL_GL_SetSwapInterval(0) != 0 ||
        SDL_GL_SetSwapInterval(1) == 0) {
        fprintf(stderr, "SDL OpenStep GL attributes failed: %s\n", SDL_GetError());
        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    checkpoint("OpenGL clear and SDL_GL_SwapWindow");
    clear_color(0.0f, 0.25f, 0.75f, 1.0f);
    clear(GL_COLOR_BUFFER_BIT);
    SDL_ClearError();
    SDL_GL_SwapWindow(window);
    if (*SDL_GetError()) {
        fprintf(stderr, "SDL_GL_SwapWindow failed: %s\n", SDL_GetError());
        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    if (SDL_GL_MakeCurrent(window, NULL) != 0 ||
        SDL_GL_MakeCurrent(window, context) != 0) {
        fprintf(stderr, "SDL_GL_MakeCurrent failed: %s\n", SDL_GetError());
        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    checkpoint("SDL_GL_DeleteContext and teardown");
    printf("openstep-sdl-gl-window-smoke: PASS GL_VERSION=%s\n",
           (const char *)get_string(GL_VERSION));
    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
