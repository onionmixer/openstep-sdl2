/* Does the audio thread actually get the priority it now asks for?
 *
 * The backend prints its report when the device closes, and that report now
 * carries base/current/max priority and the callback thread's SDL-mutex
 * waiting.  This opens a device, feeds it SILENCE for a few seconds and
 * closes it: no tone, nothing to listen to, just the four numbers -- which
 * is what has to be right before spending four game runs on the A/B.
 *
 *   cc -m486 -O -D__OPENSTEP__ -I/LocalDeveloper/Headers/SDL2 \
 *      sdlaudioprio.c /LocalDeveloper/Libraries/libSDL2.a -lm \
 *      -framework AppKit -framework Foundation -framework SoundKit \
 *      -o sdlaudioprio
 *
 *   ./sdlaudioprio [seconds]
 *
 * Run it under the same environment variables as snd-ab.sh to see what each
 * arm does to the priorities.
 */
#include <stdio.h>
#include <stdlib.h>
#include "SDL.h"

static Uint32 callbacks = 0;

static void FillSilence(void *unused, Uint8 *stream, int len)
{
    (void)unused;
    SDL_memset(stream, 0, (size_t)len);
    ++callbacks;
}

int main(int argc, char **argv)
{
    SDL_AudioSpec want, have;
    SDL_AudioDeviceID dev;
    int seconds = 5;
    const char *s;

    if (argc > 1) seconds = atoi(argv[1]);
    if (seconds < 1) seconds = 1;

    if (SDL_Init(SDL_INIT_AUDIO) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }

    s = SDL_getenv("SDL_OPENSTEP_MUTEX");
    printf("SDL_OPENSTEP_MUTEX=%s\n", s ? s : "(unset -> block)");
    s = SDL_getenv("SDL_OPENSTEP_THREAD_PRIORITY");
    printf("SDL_OPENSTEP_THREAD_PRIORITY=%s\n", s ? s : "(unset -> on)");
    s = SDL_getenv("SDL_OPENSTEP_PRIORITY_BOOST");
    printf("SDL_OPENSTEP_PRIORITY_BOOST=%s\n", s ? s : "(unset -> 10)");

    SDL_memset(&want, 0, sizeof(want));
    want.freq = 22050;          /* deliberately not the device rate: this is
                                   the shape both games ask for, so the
                                   conversion stream is in the path too */
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = FillSilence;

    dev = SDL_OpenAudioDevice(NULL, 0, &want, &have,
                              SDL_AUDIO_ALLOW_ANY_CHANGE);
    if (dev == 0) {
        fprintf(stderr, "SDL_OpenAudioDevice: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    printf("device: %d Hz, %d channels, %d frames a callback\n",
           have.freq, (int)have.channels, (int)have.samples);

    SDL_PauseAudioDevice(dev, 0);
    SDL_Delay((Uint32)seconds * 1000U);
    printf("%u callbacks in %d s\n", (unsigned)callbacks, seconds);

    SDL_CloseAudioDevice(dev);   /* the report comes out of here */
    SDL_Quit();
    return 0;
}
