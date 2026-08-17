/* Exercise Mesa 3.4.2 OSMesa contexts through standard SDL window rebuilds.
   No user interaction is required: the hidden AppKit window is resized and
   restyled, two public SDL_GLContext values are rebound and swapped, then
   both are deleted through the final libSDL2.a. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_opengl.h"

typedef const GLubyte *(APIENTRY *GetStringProc)(GLenum name);
typedef void (APIENTRY *ClearColorProc)(GLclampf red, GLclampf green,
                                        GLclampf blue, GLclampf alpha);
typedef void (APIENTRY *ClearProc)(GLbitfield mask);
typedef void (APIENTRY *GenTexturesProc)(GLsizei count, GLuint *textures);
typedef void (APIENTRY *BindTextureProc)(GLenum target, GLuint texture);
typedef GLboolean (APIENTRY *IsTextureProc)(GLuint texture);

static void Checkpoint(const char *name)
{
    fprintf(stdout, "openstep-sdl-final-archive-gl-lifecycle-smoke: %s\n", name);
    fflush(stdout);
}

static int DrawAndSwap(SDL_Window *window, SDL_GLContext context,
                       ClearColorProc clear_color, ClearProc clear,
                       float red, float green, float blue)
{
    Checkpoint("draw make-current");
    if (SDL_GL_MakeCurrent(window, context) != 0) return -1;
    Checkpoint("draw clear+swap");
    clear_color(red, green, blue, 1.0f);
    clear(GL_COLOR_BUFFER_BIT);
    SDL_ClearError();
    SDL_GL_SwapWindow(window);
    if (*SDL_GetError()) return -1;
    Checkpoint("draw complete");
    return 0;
}

int main(void)
{
    SDL_Window *window = NULL;
    SDL_GLContext first = NULL;
    SDL_GLContext second = NULL;
    GetStringProc get_string;
    ClearColorProc clear_color;
    ClearProc clear;
    GenTexturesProc gen_textures;
    BindTextureProc bind_texture;
    IsTextureProc is_texture;
    GLuint shared_texture = 0;
    int width;
    int height;
    int result = 0;

    if (!freopen("/tmp/SDL20/log/openstep-sdl-final-archive-gl-lifecycle.log", "w", stdout)) {
        return 1;
    }
    Checkpoint("video init");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    Checkpoint("create hidden window");
    window = SDL_CreateWindow("SDL2 OPENSTEP GL lifecycle smoke",
                              SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              64, 48, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN |
                              SDL_WINDOW_RESIZABLE);
    if (window == NULL) {
        result = 2;
        goto done;
    }
    if (SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 0) != 0) {
        result = 3;
        goto done;
    }
    Checkpoint("create first context");
    first = SDL_GL_CreateContext(window);
    if (first == NULL) {
        result = 4;
        goto done;
    }
    get_string = (GetStringProc)SDL_GL_GetProcAddress("glGetString");
    clear_color = (ClearColorProc)SDL_GL_GetProcAddress("glClearColor");
    clear = (ClearProc)SDL_GL_GetProcAddress("glClear");
    gen_textures = (GenTexturesProc)SDL_GL_GetProcAddress("glGenTextures");
    bind_texture = (BindTextureProc)SDL_GL_GetProcAddress("glBindTexture");
    is_texture = (IsTextureProc)SDL_GL_GetProcAddress("glIsTexture");
    if (get_string == NULL || clear_color == NULL || clear == NULL ||
        gen_textures == NULL || bind_texture == NULL || is_texture == NULL ||
        get_string(GL_VERSION) == NULL) {
        result = 5;
        goto done;
    }
    Checkpoint("create shared second context");
    gen_textures(1, &shared_texture);
    bind_texture(GL_TEXTURE_2D, shared_texture);
    if (shared_texture == 0 || !is_texture(shared_texture) ||
        SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1) != 0) {
        result = 6;
        goto done;
    }
    second = SDL_GL_CreateContext(window);
    if (second == NULL || SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 0) != 0) {
        result = 7;
        goto done;
    }
    if (SDL_GL_MakeCurrent(window, second) != 0 || !is_texture(shared_texture)) {
        result = 8;
        goto done;
    }
    Checkpoint("initial swaps");
    if (DrawAndSwap(window, first, clear_color, clear, 0.1f, 0.2f, 0.3f) != 0 ||
        DrawAndSwap(window, second, clear_color, clear, 0.3f, 0.2f, 0.1f) != 0) {
        result = 9;
        goto done;
    }

    Checkpoint("resize window");
    SDL_SetWindowSize(window, 80, 60);
    SDL_PumpEvents();
    if (DrawAndSwap(window, first, clear_color, clear, 0.2f, 0.4f, 0.6f) != 0) {
        result = 10;
        goto done;
    }
    SDL_GL_GetDrawableSize(window, &width, &height);
    if (width != 80 || height != 60) {
        result = 11;
        goto done;
    }

    Checkpoint("rebuild borderless/nonresizable");
    SDL_SetWindowResizable(window, SDL_FALSE);
    SDL_SetWindowBordered(window, SDL_FALSE);
    SDL_PumpEvents();
    if (DrawAndSwap(window, second, clear_color, clear, 0.6f, 0.4f, 0.2f) != 0) {
        result = 12;
        goto done;
    }
    SDL_GL_GetDrawableSize(window, &width, &height);
    if (width != 80 || height != 60) {
        result = 13;
        goto done;
    }

    Checkpoint("rebuild bordered/resizable");
    SDL_SetWindowBordered(window, SDL_TRUE);
    SDL_SetWindowResizable(window, SDL_TRUE);
    SDL_PumpEvents();
    if (DrawAndSwap(window, first, clear_color, clear, 0.7f, 0.1f, 0.5f) != 0) {
        result = 14;
        goto done;
    }

    Checkpoint("enter fullscreen");
    SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP);
    SDL_PumpEvents();
    if (DrawAndSwap(window, first, clear_color, clear, 0.5f, 0.1f, 0.7f) != 0) {
        result = 15;
        goto done;
    }
    SDL_GL_GetDrawableSize(window, &width, &height);
    if (width < 80 || height < 60) {
        result = 16;
        goto done;
    }
    Checkpoint("leave fullscreen");
    SDL_SetWindowFullscreen(window, 0);
    SDL_PumpEvents();
    if (DrawAndSwap(window, second, clear_color, clear, 0.1f, 0.7f, 0.5f) != 0 ||
        SDL_GL_MakeCurrent(window, NULL) != 0) {
        result = 17;
        goto done;
    }
    SDL_GL_GetDrawableSize(window, &width, &height);
    if (width != 80 || height != 60) {
        result = 18;
    }

done:
    Checkpoint("teardown");
    if (second != NULL) SDL_GL_DeleteContext(second);
    if (first != NULL) SDL_GL_DeleteContext(first);
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-gl-lifecycle-smoke: failed checkpoint %d: %s\n",
                result, SDL_GetError());
        return result;
    }
    printf("openstep-sdl-final-archive-gl-lifecycle-smoke: PASS shared-context+resize+style+fullscreen-rebuild\n");
    return 0;
}
