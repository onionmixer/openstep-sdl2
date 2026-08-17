/* Physical SDL2/Mesa visible OpenGL swap probe through final libSDL2.a. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_opengl.h"

typedef void (APIENTRY *ClearColorProc)(GLclampf red, GLclampf green,
                                        GLclampf blue, GLclampf alpha);
typedef void (APIENTRY *ClearProc)(GLbitfield mask);
typedef void (APIENTRY *ReadPixelsProc)(GLint x, GLint y, GLsizei width,
                                        GLsizei height, GLenum format,
                                        GLenum type, GLvoid *pixels);

static void PumpFor(Uint32 milliseconds)
{
    Uint32 deadline = SDL_GetTicks() + milliseconds;
    while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
        SDL_PumpEvents();
        SDL_Delay(10);
    }
}

static int Draw(SDL_Window *window, ClearColorProc clear_color, ClearProc clear,
                ReadPixelsProc read_pixels, float red, float green, float blue)
{
    unsigned char pixel[4];

    clear_color(red, green, blue, 1.0f);
    clear(GL_COLOR_BUFFER_BIT);
    read_pixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
    if (pixel[0] < (unsigned char)(red * 255.0f - 2.0f) ||
        pixel[1] < (unsigned char)(green * 255.0f - 2.0f) ||
        pixel[2] < (unsigned char)(blue * 255.0f - 2.0f)) {
        SDL_SetError("Mesa clear/readback mismatch");
        return -1;
    }
    SDL_ClearError();
    SDL_GL_SwapWindow(window);
    return *SDL_GetError() ? -1 : 0;
}

static int Fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-physical-gl-probe: %s: %s\n", what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    SDL_Window *window = NULL;
    SDL_GLContext context = NULL;
    ClearColorProc clear_color;
    ClearProc clear;
    ReadPixelsProc read_pixels;
    int result = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-physical-gl.log", "w", stdout)) return 2;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return Fail("video init failed");
    window = SDL_CreateWindow("SDL2 Mesa OpenGL physical probe",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              480, 240, SDL_WINDOW_OPENGL);
    if (window == NULL) {
        result = Fail("OpenGL window creation failed");
        goto done;
    }
    context = SDL_GL_CreateContext(window);
    if (context == NULL) {
        result = Fail("OpenGL context creation failed");
        goto done;
    }
    clear_color = (ClearColorProc)SDL_GL_GetProcAddress("glClearColor");
    clear = (ClearProc)SDL_GL_GetProcAddress("glClear");
    read_pixels = (ReadPixelsProc)SDL_GL_GetProcAddress("glReadPixels");
    if (clear_color == NULL || clear == NULL || read_pixels == NULL) {
        result = Fail("GL entry point lookup failed");
        goto done;
    }
    if (Draw(window, clear_color, clear, read_pixels, 0.75f, 0.08f, 0.08f) != 0) {
        result = Fail("red GL presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-gl-probe: RED 3sec\n");
    fflush(stdout);
    PumpFor(3000);
    if (Draw(window, clear_color, clear, read_pixels, 0.08f, 0.15f, 0.75f) != 0) {
        result = Fail("blue GL presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-gl-probe: BLUE 30sec\n");
    fflush(stdout);
    PumpFor(30000);
    if (Draw(window, clear_color, clear, read_pixels, 0.08f, 0.65f, 0.20f) != 0) {
        result = Fail("green GL presentation failed");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-gl-probe: GREEN 3sec\n");
    fflush(stdout);
    PumpFor(3000);

done:
    if (context != NULL) SDL_GL_DeleteContext(context);
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) fprintf(stdout, "openstep-sdl-physical-gl-probe: PASS GL swaps\n");
    fflush(stdout);
    return result;
}
