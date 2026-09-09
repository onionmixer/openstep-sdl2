/*
 * openstep-sdl-scale-teapot.c -- does video make the audio break up?
 *
 * The question this answers is the one ANAYLIZE_SDL2_SOUND_OPTIMIZATION.md
 * section 8.3 asks: with the SAME audio path, does adding a picture make
 * the device run dry, and if so which picture -- the AppKit/WindowServer
 * one, the Matrox direct one, or is it just that the processor is busy?
 *
 * So this plays an eight-note scale (C4 to C5, a quarter second a note,
 * for ever) through an ordinary SDL2 callback device, and spins a teapot
 * next to it -- or does not, depending on the mode:
 *
 *      mode 0   no window at all; the main thread sleeps      (the control)
 *      mode 1   teapot through SDL_GL_SwapWindow             (AppKit present)
 *      mode 2   teapot through the Matrox present hooks      (video memory)
 *      mode 3   no window; the main thread SPINS              (CPU only)
 *
 * and an optional lock time: the main thread holds SDL_LockAudioDevice for
 * that many milliseconds every frame, which is the one thing an application
 * can do to the audio thread besides taking its processor.
 *
 * THE VERDICT IS NOT READ BY EAR.  SDL's audio loop is paced by SNDWait, so
 * it cannot run ahead of the device: if the device ran dry the wall clock
 * kept going and the run ends with FEWER callbacks than the elapsed time
 * called for.  That shortfall IS the dry time, the same number tonectl
 * (openstep-water1/tools/audio-control-tone.c) prints, so the two can be
 * put side by side.  On top of it this program times the callbacks
 * themselves: the longest gap between two callbacks, and how many gaps
 * exceeded 50/100/150/200 ms.  A gap far longer than the device buffer
 * (125 ms at freq/8) is the audio thread not getting the processor.
 *
 * WHAT IT CANNOT SEE.  The kernel pads a short descriptor with silence
 * without stopping DMA (section 1.3 of the analysis); that only shows up
 * here as a later callback, i.e. as part of the shortfall, not as its own
 * count.  Counting padded descriptors needs the backend's beginFun/endFun
 * timestamps (candidate C1), which this program cannot reach from outside.
 *
 * Reading the four modes together:
 *
 *      0 dry, 3 dry            the path itself cannot keep up -- geometry first
 *      0 clean, 1 dry, 3 clean  it is the WindowServer / present path
 *      0 clean, 1 dry, 3 dry    it is the processor, video or not
 *      1 dry, 2 clean           AppKit delivery specifically
 *
 * ONE SOURCE, TWO BINARIES, as openstep-mga-sdl-teapot.c: the plain one
 * links stock libGL.a and cannot do mode 2; the hybrid one links
 * libGL_mga.a and registers SDL's present hooks the way that demo's
 * OSMGA_SDLTEAPOT_PRESENT=3 does.
 *
 * Build on the target with build-sdl-scale-teapot.csh beside this file.
 * Run:   scaleteapot [seconds] [mode] [lockms] [width height]
 */
#include <stddef.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>     /* SDL_stdinc.h/SDL_log.h declare va_list users */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>
#include <SDL.h>
#include <GL/gl.h>

#if defined(OSMGA_SCALE_ACCEL)
#include "SDL_openstepglpresent.h"
#endif

/* Which delivery the hybrid binary reports. */
#if defined(OSMGA_SCALE_ACCEL)
extern unsigned long OSMGAMesaBufferOrigin(void);
extern int  OSMGAMesaBufferPresentMode(int on);
extern int  OSMGAMesaBufferPresentRect(unsigned long srcX, unsigned long srcY,
                                       unsigned long w, unsigned long h,
                                       long dstX, long dstY,
                                       unsigned long *verdict);
#endif

/*
 * A game's audio: 44100 stereo, 1024 frames a callback.  44100 is chosen
 * on purpose so that SDL inserts NO resampler -- the resampler is a
 * separate variable (water1 has one, quake has one), and this program is
 * about the delivery, not the conversion.  tonectl covers the other case.
 */
#define SCALE_RATE      44100
#define SCALE_CHANNELS  2
#define SCALE_FRAMES    1024
#define NOTE_MS         250

/* C4..C5, equal temperament. */
static const double notes[8] = {
    261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25
};

static double   phase = 0.0;
static long     noteFrames = 0;     /* frames played of the current note */
static int      noteIndex = 0;
static long     callbacks = 0;

/* Callback timing.  All plain counters; nothing is printed while playing. */
static Uint64   lastCallback = 0;
static Uint64   maxGapUs = 0;
static long     gapOver50 = 0, gapOver100 = 0, gapOver150 = 0, gapOver200 = 0;

static void scale_callback(void *userdata, Uint8 *stream, int len)
{
    Sint16 *out = (Sint16 *)stream;
    int frames = len / (int)(SCALE_CHANNELS * sizeof(Sint16));
    int i;
    Uint64 now = SDL_GetPerformanceCounter();
    long noteLen = (long)SCALE_RATE * NOTE_MS / 1000;
    (void)userdata;

    if (lastCallback != 0) {
        Uint64 gap = now - lastCallback;       /* microseconds on this port */
        if (gap > maxGapUs) maxGapUs = gap;
        if (gap > 50000)  gapOver50++;
        if (gap > 100000) gapOver100++;
        if (gap > 150000) gapOver150++;
        if (gap > 200000) gapOver200++;
    }
    lastCallback = now;
    callbacks++;

    for (i = 0; i < frames; i++) {
        double step = 2.0 * 3.14159265358979 * notes[noteIndex] / (double)SCALE_RATE;
        Sint16 v = (Sint16)(6000.0 * sin(phase));
        phase += step;
        if (phase > 2.0 * 3.14159265358979) phase -= 2.0 * 3.14159265358979;
        out[i * 2]     = v;
        out[i * 2 + 1] = v;
        if (++noteFrames >= noteLen) {
            noteFrames = 0;
            noteIndex = (noteIndex + 1) & 7;
            phase = 0.0;            /* a click at the note edge is intended: it marks the beat */
        }
    }
}

/* ---- the teapot, exactly as openstep-mga-sdl-teapot.c draws it ---- */

static int W = 640, H = 480;

#if defined(SCALE_NO_TEAPOT)
/* Host syntax check only: the geometry file is cut from Mesa at build time. */
static void teapot(int grid, double scale, GLenum type)
{ (void)grid; (void)scale; (void)type; }
#else
#include "teapot-geometry.h"
#endif

static void projection(void)
{
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustum(-1.0, 1.0, -0.75, 0.75, 2.0, 20.0);
    glMatrixMode(GL_MODELVIEW);
}

static void setupScene(void)
{
    GLfloat amb[4], dif[4], pos[4], lamb[4];
    GLfloat mamb[4], mdif[4], mspec[4];

    glViewport(0, 0, W, H);
    projection();
    glLoadIdentity();
    glTranslatef(0.0f, -0.2f, -6.0f);
    glRotatef(-20.0f, 1.0f, 0.0f, 0.0f);
    glDisable(GL_BLEND); glDisable(GL_DITHER);
    glDisable(GL_TEXTURE_2D); glDisable(GL_CULL_FACE);
    glShadeModel(GL_SMOOTH);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glClearDepth(1.0);
    amb[0] = 0.0f; amb[1] = 0.0f; amb[2] = 0.0f; amb[3] = 1.0f;
    dif[0] = 1.0f; dif[1] = 1.0f; dif[2] = 1.0f; dif[3] = 1.0f;
    pos[0] = 0.0f; pos[1] = 3.0f; pos[2] = 3.0f; pos[3] = 0.0f;
    lamb[0] = 0.2f; lamb[1] = 0.2f; lamb[2] = 0.2f; lamb[3] = 1.0f;
    glLightfv(GL_LIGHT0, GL_AMBIENT, amb);
    glLightfv(GL_LIGHT0, GL_DIFFUSE, dif);
    glLightfv(GL_LIGHT0, GL_POSITION, pos);
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lamb);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    mamb[0] = 0.18f; mamb[1] = 0.07f; mamb[2] = 0.03f; mamb[3] = 1.0f;
    mdif[0] = 0.9f;  mdif[1] = 0.35f; mdif[2] = 0.15f; mdif[3] = 1.0f;
    mspec[0] = 0.9f; mspec[1] = 0.9f; mspec[2] = 0.9f; mspec[3] = 1.0f;
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, mamb);
    glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, mdif);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, mspec);
    glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 50.0f);
    glClearColor(0.06f, 0.08f, 0.14f, 1.0f);
}

static void drawFrame(double angle)
{
    glClear((GLbitfield)(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
    glPushMatrix();
    glRotatef(180.0f, 1.0f, 0.0f, 0.0f);
    glRotatef((float)(angle * 57.29578), 0.0f, 1.0f, 0.0f);
    teapot(4, 1.0, GL_FILL);
    glPopMatrix();
}

static double now_s(void)
{
    struct timeval t;
    gettimeofday(&t, (struct timezone *)0);
    return (double)t.tv_sec + (double)t.tv_usec / 1e6;
}

/* Hold the audio lock for `ms' -- what a game does when it paints under
 * SDL_LockAudio.  A spin, not a sleep: a sleeping holder would give the
 * processor away and measure nothing. */
static void hold_lock(SDL_AudioDeviceID dev, int ms)
{
    double t0;
    if (ms <= 0) return;
    SDL_LockAudioDevice(dev);
    t0 = now_s();
    while ((now_s() - t0) * 1000.0 < (double)ms)
        ;
    SDL_UnlockAudioDevice(dev);
}

int main(int argc, char **argv)
{
    SDL_AudioSpec want, have;
    SDL_AudioDeviceID dev;
    SDL_Window *win = NULL;
    SDL_GLContext ctx = NULL;
    SDL_Event ev;
    int secs   = (argc > 1) ? atoi(argv[1]) : 60;
    int mode   = (argc > 2) ? atoi(argv[2]) : 0;
    int lockms = (argc > 3) ? atoi(argv[3]) : 0;
    Uint32 flags;
    double wall0, wall1, angle = 0.0;
    double expected, shortfall, elapsed;
    long frames = 0;
    int quit = 0;
    const char *delivery = "none";

    if (argc > 5) { W = atoi(argv[4]); H = atoi(argv[5]); }
    if (secs < 5)  secs = 5;
    if (secs > 600) secs = 600;
    if (mode < 0 || mode > 3) mode = 0;
    if (W < 64 || H < 64) { printf("usage: %s [seconds] [mode 0-3] [lockms] [w h]\n", argv[0]); return 2; }
#if !defined(OSMGA_SCALE_ACCEL)
    if (mode == 2) {
        printf("scaleteapot: mode 2 needs the hybrid binary (libGL_mga.a)\n");
        return 2;
    }
#endif

    flags = SDL_INIT_AUDIO;
    if (mode == 1 || mode == 2) flags |= SDL_INIT_VIDEO;
    if (SDL_Init(flags) != 0) {
        printf("SDL_Init: %s\n", SDL_GetError());
        return 2;
    }

    /* Audio first, and it starts before any window exists: the control
     * run (mode 0) and the loaded runs then share the same first region,
     * so the kernel's descriptor lead (analysis section 1.3) is the same
     * in every mode. */
    SDL_memset(&want, 0, sizeof(want));
    want.freq     = SCALE_RATE;
    want.format   = AUDIO_S16SYS;
    want.channels = SCALE_CHANNELS;
    want.samples  = SCALE_FRAMES;
    want.callback = scale_callback;
    dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (dev == 0) {
        printf("SDL_OpenAudioDevice: %s\n", SDL_GetError());
        SDL_Quit();
        return 2;
    }
    printf("scaleteapot: want %dHz fmt=0x%04X ch=%d samples=%d / "
           "have %dHz fmt=0x%04X ch=%d samples=%d\n",
           want.freq, (unsigned)want.format, want.channels, want.samples,
           have.freq, (unsigned)have.format, have.channels, have.samples);

    if (mode == 1 || mode == 2) {
        win = SDL_CreateWindow("SDL2 scale teapot", SDL_WINDOWPOS_CENTERED,
                               SDL_WINDOWPOS_CENTERED, W, H, SDL_WINDOW_OPENGL);
        if (!win) { printf("SDL_CreateWindow: %s\n", SDL_GetError()); return 2; }
        ctx = SDL_GL_CreateContext(win);
        if (!ctx) { printf("SDL_GL_CreateContext: %s\n", SDL_GetError()); return 2; }
        delivery = "AppKit (SDL_GL_SwapWindow)";
#if defined(OSMGA_SCALE_ACCEL)
        if (mode == 2) {
            /* The registration openstep-mga-sdl-teapot.c calls mode 3:
             * hand SDL the driver's three functions and run an ordinary
             * swap loop.  Static, because SDL keeps the pointer. */
            static const SDL_OpenStepGLPresent hooks = {
                SDL_OPENSTEP_GLPRESENT_ABI,
                sizeof(SDL_OpenStepGLPresent),
                OSMGAMesaBufferOrigin,
                OSMGAMesaBufferPresentMode,
                OSMGAMesaBufferPresentRect
            };
            if (OSMGAMesaBufferOrigin()) {
                SDL_SetWindowData(win, SDL_OPENSTEP_GLPRESENT_KEY, (void *)&hooks);
                delivery = "Matrox present hooks (video memory)";
            } else {
                delivery = "AppKit -- the driver did NOT claim the surface, so mode 2 fell back";
            }
        }
#endif
        setupScene();
    }

    printf("scaleteapot: %d s, mode %d (%s), lock %d ms/frame, delivery: %s\n",
           secs, mode,
           (mode == 0) ? "no window, main sleeps" :
           (mode == 1) ? "teapot, AppKit" :
           (mode == 2) ? "teapot, Matrox" : "no window, main spins",
           lockms, delivery);
    fflush(stdout);

    SDL_PauseAudioDevice(dev, 0);
    wall0 = now_s();

    if (mode == 0 && lockms == 0) {
        /* One long sleep, as tonectl: a polling loop here would be this
         * program competing with its own audio thread. */
        SDL_Delay((Uint32)secs * 1000);
    } else {
        while (!quit && (now_s() - wall0) < (double)secs) {
            if (win) {
                drawFrame(angle); angle += 0.05;
                glFinish();
                SDL_GL_SwapWindow(win);
                while (SDL_PollEvent(&ev)) { if (ev.type == SDL_QUIT) quit = 1; }
            }
            hold_lock(dev, lockms);
            frames++;
            /* mode 3 and the locked mode 0 spin here on purpose */
        }
    }
    wall1 = now_s();
    elapsed = wall1 - wall0;
    SDL_PauseAudioDevice(dev, 1);

    /*
     * The number that matters, computed from the wall clock actually
     * elapsed (a loaded loop overshoots its deadline; charging that to the
     * audio thread would be wrong).
     */
    expected  = elapsed * (double)SCALE_RATE / (double)SCALE_FRAMES;
    shortfall = expected - (double)callbacks;
    if (shortfall < 0.0) shortfall = 0.0;

    printf("\nscaleteapot: %ld callbacks in %.0f ms; expected %.1f; short by %.1f"
           " = %.2f%% (%.0f ms of dry device)\n",
           callbacks, elapsed * 1000.0, expected, shortfall,
           (expected > 0.0) ? 100.0 * shortfall / expected : 0.0,
           shortfall * (double)SCALE_FRAMES * 1000.0 / (double)SCALE_RATE);
    printf("scaleteapot: callback gap max %.1f ms; gaps over 50/100/150/200 ms: %ld/%ld/%ld/%ld"
           "  (nominal %.1f ms a callback, %d ms a device buffer at freq/8)\n",
           (double)maxGapUs / 1000.0, gapOver50, gapOver100, gapOver150, gapOver200,
           (double)SCALE_FRAMES * 1000.0 / (double)SCALE_RATE, 125);
    if (win) {
        printf("scaleteapot: %ld frames, %.2f fps, %.1f ms a frame\n",
               frames, (double)frames / elapsed, elapsed * 1000.0 / (double)(frames ? frames : 1));
    } else if (mode == 3 || lockms) {
        printf("scaleteapot: main thread ran %ld loop turns\n", frames);
    }

    SDL_CloseAudioDevice(dev);
    if (ctx) SDL_GL_DeleteContext(ctx);
    if (win) SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
