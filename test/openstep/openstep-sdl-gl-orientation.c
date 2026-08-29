/*
 * Which way up does a frame reach the screen -- and does the 2D path agree
 * with the GL path?
 *
 * NOTHING IN THIS PORT CHECKED EITHER.  The GL tests clear a whole window to
 * one colour, or read back with glReadPixels -- which answers in GL's own
 * coordinates and so cannot see the presentation copy at all.  A vertical
 * inversion passes every one of them, and one did: an operator reported an
 * upside-down teapot.
 *
 * So this draws four quadrants in four colours -- asymmetric in BOTH axes,
 * because a mistaken row flip and a mistaken column flip are different
 * failures -- once through the 2D surface path and once through GL, in the
 * same window, and reports two things per pass:
 *
 *   what the presentation bitmap HOLDS   printed here, read through the
 *                                        backend's own window data
 *   what the screen SHOWS                the operator's eye, which is the
 *                                        only instrument for that
 *
 * Both are needed.  The bitmap tells us what SDL produced; only the screen
 * tells us which end of that bitmap AppKit puts at the top, and that is the
 * fact every flip in this file depends on.
 *
 * Wanted, in both passes:
 *
 *      RED    GREEN        <- top of the screen
 *      BLUE   WHITE        <- bottom
 *
 * Red at the TOP LEFT.  If the pair is upside down, red is at the bottom.
 * If it is mirrored left-to-right, red is on the right.
 *
 * This reaches into the backend's private window data on purpose: the
 * presentation bitmap is not reachable through the public API, and adding a
 * symbol for it would change the archive's exact 836-symbol manifest.  The
 * port's other window tests already compile against these internal headers.
 */
#include <stdio.h>
#include <string.h>
#include <SDL.h>
#include <GL/gl.h>

#include "SDL_sysvideo.h"
#include "video/openstep/SDL_openstepvideo.h"

#define W 240
#define H 180
#define HOLD_MS 6000

static int failures;

static const void *
presentPixels(SDL_Window *window)
{
    SDL_OpenStepWindowData *data;

    if (!window) return NULL;
    data = (SDL_OpenStepWindowData *)window->driverdata;
    return data ? data->present_pixels : NULL;
}

/*
 * The bitmap is 24-bit RGB, w*3 bytes a row.  WHICH END IS THE TOP is what
 * this test is trying to find out, so nothing here assumes it: rows are
 * named by index and the operator says which index is the top.
 */
/*
 * GROUND TRUTH, established on hardware 2026-08-29 and confirmed by an
 * operator looking at the screen: the presentation bitmap is BOTTOM-UP.
 * Its low row indices are the bottom of the picture, and AppKit puts them
 * at the bottom.  All four cases -- 2D and GL, software and accelerated --
 * produced this same layout, which is what says neither SDL's delivery nor
 * the Matrox driver reverses anything.
 *
 *      row 3H/4   RED    GREEN      <- the top of the picture
 *      row  H/4   BLUE   WHITE      <- the bottom
 *
 * So this is now an assertion rather than a printout.  A future change that
 * flips either path fails here instead of reaching an operator's eye.
 */
static void
sample(const unsigned char *px, int rowIndex, int atRight, const char *name,
       int wr, int wg, int wb)
{
    int x = atRight ? (W * 3 / 4) : (W / 4);
    const unsigned char *p = px + ((rowIndex * W) + x) * 3;
    int dr = (int)p[0] - wr, dg = (int)p[1] - wg, db = (int)p[2] - wb;

    if (dr < 0) dr = -dr;
    if (dg < 0) dg = -dg;
    if (db < 0) db = -db;
    if (dr > 24 || dg > 24 || db > 24) {
        printf("      FAIL %-18s wanted %3d %3d %3d, found %3d %3d %3d\n",
               name, wr, wg, wb, p[0], p[1], p[2]);
        failures++;
    } else {
        printf("      ok   %-18s %3d %3d %3d\n", name, p[0], p[1], p[2]);
    }
}

static void
report(SDL_Window *win, const char *pass)
{
    const unsigned char *px = (const unsigned char *)presentPixels(win);

    printf("   %s -- what the bitmap holds\n", pass);
    if (!px) {
        printf("      NOT READABLE -- proves nothing\n");
        failures++;
        return;
    }
    sample(px, H / 4,     0, "row H/4  left",    0,   0, 255);  /* BLUE  */
    sample(px, H / 4,     1, "row H/4  right",  255, 255, 255);  /* WHITE */
    sample(px, H * 3 / 4, 0, "row 3H/4 left",   255,   0,   0);  /* RED   */
    sample(px, H * 3 / 4, 1, "row 3H/4 right",    0, 255,   0);  /* GREEN */
}

/* 2D: SDL surfaces are top-down, so y counts from the top of the picture. */
static void
paintSurface(SDL_Surface *s)
{
    int x, y;

    for (y = 0; y < H; y++) {
        Uint32 *row = (Uint32 *)((Uint8 *)s->pixels + y * s->pitch);
        for (x = 0; x < W; x++) {
            int top = (y < H / 2), left = (x < W / 2);
            Uint32 c;
            if (top && left)        c = 0x00FF0000;   /* RED    */
            else if (top && !left)  c = 0x0000FF00;   /* GREEN  */
            else if (!top && left)  c = 0x000000FF;   /* BLUE   */
            else                    c = 0x00FFFFFF;   /* WHITE  */
            row[x] = c;
        }
    }
}

/*
 * GL: y counts from the BOTTOM, so the quadrant that must appear at the top
 * of the screen is the one at y = +1 here.  Nothing in this function knows
 * how the frame is delivered; that is the point.
 */
static void
paintGL(void)
{
    struct { double x0, y0, x1, y1; float r, g, b; } q[4] = {
        { -1.0,  0.0,  0.0,  1.0,  1.0f, 0.0f, 0.0f },   /* top left  RED   */
        {  0.0,  0.0,  1.0,  1.0,  0.0f, 1.0f, 0.0f },   /* top right GREEN */
        { -1.0, -1.0,  0.0,  0.0,  0.0f, 0.0f, 1.0f },   /* bot left  BLUE  */
        {  0.0, -1.0,  1.0,  0.0,  1.0f, 1.0f, 1.0f }    /* bot right WHITE */
    };
    int i;

    glViewport(0, 0, W, H);
    glMatrixMode(GL_PROJECTION); glLoadIdentity();
    glOrtho(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0);
    glMatrixMode(GL_MODELVIEW); glLoadIdentity();
    glDisable(GL_DEPTH_TEST); glDisable(GL_LIGHTING);
    glDisable(GL_DITHER); glDisable(GL_BLEND); glDisable(GL_CULL_FACE);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    for (i = 0; i < 4; i++) {
        glColor3f(q[i].r, q[i].g, q[i].b);
        glBegin(GL_QUADS);
          glVertex2d(q[i].x0, q[i].y0); glVertex2d(q[i].x1, q[i].y0);
          glVertex2d(q[i].x1, q[i].y1); glVertex2d(q[i].x0, q[i].y1);
        glEnd();
    }
}

static void
hold(const char *what)
{
    Uint32 end = SDL_GetTicks() + HOLD_MS;
    SDL_Event ev;

    printf("   >>> LOOK NOW: %s.  Where is RED?  (%d seconds)\n", what,
           HOLD_MS / 1000);
    fflush(stdout);
    while ((Sint32)(end - SDL_GetTicks()) > 0) {
        while (SDL_PollEvent(&ev)) { }
        SDL_Delay(50);
    }
}

int
main(int argc, char **argv)
{
    SDL_Window *win;
    SDL_Surface *surf;
    SDL_GLContext ctx;

    (void)argc; (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        printf("SDL_Init: %s\n", SDL_GetError()); return 2;
    }
    printf("\nwanted on the screen, both passes:\n"
           "\n      RED    GREEN      <- top\n"
           "      BLUE   WHITE       <- bottom\n\n");

    /* ---- pass one: the 2D surface path ---- */
    win = SDL_CreateWindow("2D: red should be TOP LEFT",
                           SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                           W, H, 0);
    if (!win) { printf("SDL_CreateWindow: %s\n", SDL_GetError()); return 2; }
    surf = SDL_GetWindowSurface(win);
    if (!surf) { printf("SDL_GetWindowSurface: %s\n", SDL_GetError()); return 2; }
    paintSurface(surf);
    SDL_UpdateWindowSurface(win);
    report(win, "2D");
    hold("the 2D window");
    SDL_DestroyWindow(win);

    /* ---- pass two: the GL path ---- */
    win = SDL_CreateWindow("GL: red should be TOP LEFT",
                           SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                           W, H, SDL_WINDOW_OPENGL);
    if (!win) { printf("SDL_CreateWindow: %s\n", SDL_GetError()); return 2; }
    ctx = SDL_GL_CreateContext(win);
    if (!ctx) { printf("SDL_GL_CreateContext: %s\n", SDL_GetError()); return 2; }
    paintGL();
    SDL_GL_SwapWindow(win);
    report(win, "GL");
    hold("the GL window");
    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(win);

    SDL_Quit();
    printf("\n%s\n", failures ? "OPENSTEP_SDL_ORIENTATION=fail"
                               : "OPENSTEP_SDL_ORIENTATION=pass");
    printf("   (the bitmap layout is checked here; that RED is at the TOP\n"
           "    LEFT on the screen still needs an eye, and was confirmed.)\n");
    return failures ? 1 : 0;
}
