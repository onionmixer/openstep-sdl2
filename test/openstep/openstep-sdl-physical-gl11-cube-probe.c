/* Verify the OpenGL 1.1 fixed-function surface used by SDL's testgl2 sample.
   Mesa 3.4.2 is GL 1.2, so this intentionally asks only for its guaranteed
   core entry points instead of claiming availability of later GL APIs. */
#include <stdio.h>

#include "SDL.h"
#include "SDL_opengl.h"

typedef const GLubyte *(APIENTRY *GetStringProc)(GLenum name);
typedef GLenum (APIENTRY *GetErrorProc)(void);
typedef void (APIENTRY *ClearColorProc)(GLclampf, GLclampf, GLclampf, GLclampf);
typedef void (APIENTRY *ClearProc)(GLbitfield);
typedef void (APIENTRY *BeginProc)(GLenum);
typedef void (APIENTRY *Color3fvProc)(const GLfloat *);
typedef void (APIENTRY *Vertex3fvProc)(const GLfloat *);
typedef void (APIENTRY *EndProc)(void);
typedef void (APIENTRY *MatrixModeProc)(GLenum);
typedef void (APIENTRY *RotatefProc)(GLfloat, GLfloat, GLfloat, GLfloat);
typedef void (APIENTRY *LoadIdentityProc)(void);
typedef void (APIENTRY *OrthoProc)(GLdouble, GLdouble, GLdouble, GLdouble,
                                   GLdouble, GLdouble);
typedef void (APIENTRY *EnableProc)(GLenum);
typedef void (APIENTRY *DepthFuncProc)(GLenum);
typedef void (APIENTRY *ShadeModelProc)(GLenum);
typedef void (APIENTRY *ViewportProc)(GLint, GLint, GLsizei, GLsizei);

static int
RequireProc(const char *name, void **result)
{
    *result = SDL_GL_GetProcAddress(name);
    if (*result == NULL) {
        fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: missing %s: %s\n",
                name, SDL_GetError());
        return -1;
    }
    return 0;
}

int
main(int argc, char **argv)
{
    SDL_Window *window = NULL;
    SDL_GLContext context = NULL;
    GetStringProc get_string;
    GetErrorProc get_error;
    ClearColorProc clear_color;
    ClearProc clear;
    BeginProc begin;
    Color3fvProc color3fv;
    Vertex3fvProc vertex3fv;
    EndProc end;
    MatrixModeProc matrix_mode;
    RotatefProc rotatef;
    LoadIdentityProc load_identity;
    OrthoProc ortho;
    EnableProc enable;
    DepthFuncProc depth_func;
    ShadeModelProc shade_model;
    ViewportProc viewport;
    void *proc;
    Uint32 deadline;
    int width;
    int height;
    int result = 1;
    GLfloat color[4][3] = {
        { 1.0f, 0.1f, 0.1f }, { 0.1f, 1.0f, 0.1f },
        { 0.1f, 0.2f, 1.0f }, { 1.0f, 1.0f, 0.1f }
    };
    GLfloat vertex[4][3] = {
        { -0.8f, -0.7f, 0.0f }, { 0.8f, -0.7f, 0.0f },
        { 0.8f, 0.7f, 0.0f }, { -0.8f, 0.7f, 0.0f }
    };

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-physical-gl11-cube.log", "w", stdout)) {
        return 2;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) goto done;
    window = SDL_CreateWindow("SDL2 Mesa GL 1.1 fixed-function probe",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              480, 240, SDL_WINDOW_OPENGL);
    if (window == NULL) goto done;
    context = SDL_GL_CreateContext(window);
    if (context == NULL) goto done;

#define REQUIRE_GL(member, symbol, type) \
    if (RequireProc(symbol, &proc) != 0) goto done; \
    member = (type)proc
    REQUIRE_GL(get_string, "glGetString", GetStringProc);
    REQUIRE_GL(get_error, "glGetError", GetErrorProc);
    REQUIRE_GL(clear_color, "glClearColor", ClearColorProc);
    REQUIRE_GL(clear, "glClear", ClearProc);
    REQUIRE_GL(begin, "glBegin", BeginProc);
    REQUIRE_GL(color3fv, "glColor3fv", Color3fvProc);
    REQUIRE_GL(vertex3fv, "glVertex3fv", Vertex3fvProc);
    REQUIRE_GL(end, "glEnd", EndProc);
    REQUIRE_GL(matrix_mode, "glMatrixMode", MatrixModeProc);
    REQUIRE_GL(rotatef, "glRotatef", RotatefProc);
    REQUIRE_GL(load_identity, "glLoadIdentity", LoadIdentityProc);
    REQUIRE_GL(ortho, "glOrtho", OrthoProc);
    REQUIRE_GL(enable, "glEnable", EnableProc);
    REQUIRE_GL(depth_func, "glDepthFunc", DepthFuncProc);
    REQUIRE_GL(shade_model, "glShadeModel", ShadeModelProc);
    REQUIRE_GL(viewport, "glViewport", ViewportProc);
#undef REQUIRE_GL

    SDL_GL_GetDrawableSize(window, &width, &height);
    viewport(0, 0, width, height);
    matrix_mode(GL_PROJECTION);
    load_identity();
    ortho(-1.5, 1.5, -1.5, 1.5, -2.0, 2.0);
    matrix_mode(GL_MODELVIEW);
    load_identity();
    enable(GL_DEPTH_TEST);
    depth_func(GL_LESS);
    shade_model(GL_SMOOTH);
    fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: GL_VERSION=%s\n",
            (const char *)get_string(GL_VERSION));
    fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: START 30sec\n");
    fflush(stdout);
    deadline = SDL_GetTicks() + 30000;
    while ((Sint32)(deadline - SDL_GetTicks()) > 0) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) goto done;
        }
        clear_color(0.04f, 0.04f, 0.04f, 1.0f);
        clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        begin(GL_QUADS);
        color3fv(color[0]); vertex3fv(vertex[0]);
        color3fv(color[1]); vertex3fv(vertex[1]);
        color3fv(color[2]); vertex3fv(vertex[2]);
        color3fv(color[3]); vertex3fv(vertex[3]);
        end();
        rotatef(2.0f, 0.0f, 0.0f, 1.0f);
        if (get_error() != GL_NO_ERROR) {
            fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: GL error\n");
            goto done;
        }
        SDL_ClearError();
        SDL_GL_SwapWindow(window);
        if (*SDL_GetError()) {
            fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: swap: %s\n", SDL_GetError());
            goto done;
        }
        SDL_Delay(16);
    }
    result = 0;

done:
    if (context != NULL) SDL_GL_DeleteContext(context);
    if (window != NULL) SDL_DestroyWindow(window);
    SDL_Quit();
    if (result == 0) fprintf(stdout, "openstep-sdl-physical-gl11-cube-probe: PASS\n");
    fflush(stdout);
    return result;
}
