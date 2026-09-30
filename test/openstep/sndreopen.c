/*
 * sndreopen -- open, play briefly, close, and open again, many times.
 *
 *   sndreopen <cycles> [max-ms] [seed]
 *
 * The shape is Quake's S_Init (SDL_OpenAudio, close, SDL_OpenAudio again)
 * repeated: each cycle opens the default device at 44100 Hz stereo 16-bit,
 * unpauses it playing silence, sleeps a pseudo-random
 * 0..max-ms (a fixed LCG, so a seed replays the same schedule), and closes
 * it.  One line per cycle goes to stderr unbuffered, so a crash leaves the
 * cycle it died in as the last line.  Written for the stream-close race in
 * openstep-sdl20/docs/PLAN_RELEASE_OPENSTEP5.md 12-13.
 */
#include <stdio.h>
#include <stdlib.h>
#include "SDL.h"

static void SDLCALL quiet(void *userdata, Uint8 *stream, int len)
{
    (void)userdata;
    SDL_memset(stream, 0, (size_t)len);    /* silence: the buffers flow all the same */
}

int main(int argc, char **argv)
{
    int cycles, maxms = 300, i, failures = 0;
    unsigned long seed = 1;
    SDL_AudioSpec want, have;

    if (argc < 2) {
        fprintf(stderr, "usage: sndreopen <cycles> [max-ms] [seed]\n");
        return 2;
    }
    cycles = atoi(argv[1]);
    if (argc > 2) maxms = atoi(argv[2]);
    if (argc > 3) seed = (unsigned long)atol(argv[3]);
    if (maxms < 1) maxms = 1;
    setbuf(stderr, NULL);
    if (SDL_Init(SDL_INIT_AUDIO) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    SDL_zero(want);
    want.freq = 44100;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = quiet;
    for (i = 1; i <= cycles; ++i) {
        SDL_AudioDeviceID dev;
        int ms;
        seed = seed * 1103515245UL + 12345UL;
        ms = (int)((seed >> 16) % (unsigned long)(maxms + 1));
        dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
        if (dev == 0) {
            fprintf(stderr, "cycle %d: open failed: %s\n", i, SDL_GetError());
            ++failures;
            continue;
        }
        SDL_PauseAudioDevice(dev, 0);
        SDL_Delay((Uint32)ms);
        SDL_CloseAudioDevice(dev);
        fprintf(stderr, "cycle %d: %d ms ok\n", i, ms);
    }
    SDL_Quit();
    fprintf(stderr, "SNDREOPEN DONE cycles %d failures %d\n", cycles, failures);
    return failures ? 1 : 0;
}
