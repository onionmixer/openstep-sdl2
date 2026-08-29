/*
 * When SDL2 stops stamping, does the window still show the right frame?
 *
 * THE FAILURE THIS EXISTS FOR is silent.  While SDL2 delivers a GL frame
 * straight from video memory, the driver stands its read-back down and the
 * caller's array goes stale -- deliberately, that is the whole saving.  The
 * moment anything makes SDL2 fall back to the ordinary AppKit path (focus
 * lost, the window moved, a refusal, the application unregistering), that
 * array is what gets drawn.  If nothing refreshes it, the window shows the
 * frame that was there when the stamping began, or the black it was
 * allocated with, and NOTHING reports an error.
 *
 * The driver already answers this, and the answer was worth finding rather
 * than assuming: every mirror path checks `if (bufPresent) return;` BEFORE
 * it clears the dirty mark, so the mark set at the last render start
 * SURVIVES the whole stamping run.  Leaving present mode therefore finds it
 * still set, and the next flush copies the surface back.
 *
 * A change was written to set that mark explicitly on leaving present mode.
 * This test refused to fail without it -- checked by disabling it and
 * rebuilding -- so the change was reverted rather than shipped as a fix for
 * something that does not happen.  What remains is this test, guarding an
 * invariant that nothing else states.
 *
 * It is written the hard way round on purpose:
 *
 *   1. draw a picture, swap -- SDL2 stamps it
 *   2. unregister the hooks           <- the fallback
 *   3. swap AGAIN WITHOUT DRAWING ANYTHING
 *   4. the presentation bitmap must hold the picture from step 1
 *
 * Step 3 is the point.  A test that drew a new frame first would pass with
 * or without the fix, because drawing is what sets the dirty mark.
 *
 * Reaching into the backend's private window data is how the bitmap is read;
 * the port's other window tests compile against the same internal headers,
 * and adding a public symbol for it would change the archive's exact
 * 836-symbol manifest.
 */
#include <stdio.h>
#include <SDL.h>
#include <GL/gl.h>

#include "SDL_sysvideo.h"
#include "video/openstep/SDL_openstepvideo.h"
#include "video/openstep/SDL_openstepglpresent.h"

#include "OpenStepMGAMesaBuffer.h"

#define W 240
#define H 180

static int failures;

static const unsigned char *
presentPixels(SDL_Window *window)
{
    SDL_OpenStepWindowData *d;

    if (!window) return NULL;
    d = (SDL_OpenStepWindowData *)window->driverdata;
    return d ? (const unsigned char *)d->present_pixels : NULL;
}

static void
check(SDL_Window *win, const char *what, int r, int g, int b)
{
    const unsigned char *px = presentPixels(win);
    const unsigned char *p;
    int dr, dg, db;

    if (!px) {
        printf("   FAIL %-28s no presentation bitmap\n", what);
        failures++;
        return;
    }
    /* Middle of the picture; the whole frame is one colour in this test, so
     * one sample answers it and a corner would only add an edge case. */
    p = px + (((H / 2) * W) + (W / 2)) * 3;
    dr = (int)p[0] - r; dg = (int)p[1] - g; db = (int)p[2] - b;
    if (dr < 0) dr = -dr;
    if (dg < 0) dg = -dg;
    if (db < 0) db = -db;
    if (dr > 24 || dg > 24 || db > 24) {
        printf("   FAIL %-28s wanted %3d %3d %3d, found %3d %3d %3d\n",
               what, r, g, b, p[0], p[1], p[2]);
        failures++;
    } else {
        printf("   ok   %-28s %3d %3d %3d\n", what, p[0], p[1], p[2]);
    }
}

static void
paint(float r, float g, float b)
{
    glClearColor(r, g, b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
}

int
main(int argc, char **argv)
{
    static const SDL_OpenStepGLPresent hooks = {
        SDL_OPENSTEP_GLPRESENT_ABI,
        sizeof(SDL_OpenStepGLPresent),
        OSMGAMesaBufferOrigin,
        OSMGAMesaBufferPresentMode,
        OSMGAMesaBufferPresentRect
    };
    SDL_Window *win;
    SDL_GLContext ctx;
    int i;

    (void)argc; (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        printf("SDL_Init: %s\n", SDL_GetError()); return 2;
    }
    win = SDL_CreateWindow("stamp fallback", SDL_WINDOWPOS_CENTERED,
                           SDL_WINDOWPOS_CENTERED, W, H, SDL_WINDOW_OPENGL);
    if (!win) { printf("SDL_CreateWindow: %s\n", SDL_GetError()); return 2; }
    ctx = SDL_GL_CreateContext(win);
    if (!ctx) { printf("SDL_GL_CreateContext: %s\n", SDL_GetError()); return 2; }

    if (OSMGAMesaBufferOrigin() == 0UL) {
        printf("NOT TESTED -- no accelerated surface, so there is no stamp\n"
               "to fall back FROM and this proves nothing\n");
        return 1;
    }

    glViewport(0, 0, W, H);
    SDL_SetWindowData(win, SDL_OPENSTEP_GLPRESENT_KEY, (void *)&hooks);

    /*
     * Several stamped frames, not one: the first swap is where the lease is
     * taken, and a fallback from a lease one frame old is not the same test
     * as a fallback from a lease that has been running.
     */
    for (i = 0; i < 5; i++) {
        paint(0.0f, 0.0f, 1.0f);            /* BLUE */
        SDL_GL_SwapWindow(win);
    }
    printf("\n   five blue frames delivered; present mode %s\n",
           OSMGAMesaBufferOrigin() ? "engaged" : "not engaged");

    /* Now take the hooks away and swap WITHOUT drawing.  Nothing marks the
     * surface dirty except leaving present mode. */
    SDL_SetWindowData(win, SDL_OPENSTEP_GLPRESENT_KEY, NULL);
    SDL_GL_SwapWindow(win);
    check(win, "fallback, nothing redrawn", 0, 0, 255);

    /* And the ordinary path still works afterwards. */
    paint(0.0f, 1.0f, 0.0f);                /* GREEN */
    SDL_GL_SwapWindow(win);
    check(win, "ordinary path after that", 0, 255, 0);

    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(win);
    SDL_Quit();
    printf("\n%s\n", failures ? "OPENSTEP_SDL_STAMP_FALLBACK=fail"
                              : "OPENSTEP_SDL_STAMP_FALLBACK=pass");
    return failures ? 1 : 0;
}
