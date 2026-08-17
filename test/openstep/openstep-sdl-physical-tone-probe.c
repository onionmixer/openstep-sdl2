/* GCD/WindowServer SoundKit stability check through final libSDL2.a.
   It produces a 441 Hz square wave at about -24 dBFS for one minute. */
#include <stdio.h>

#include "SDL.h"

#define PLAY_MILLISECONDS 60000

static SDL_atomic_t callback_count;
static unsigned long phase;

static void SDLCALL FillTone(void *userdata, Uint8 *stream, int length)
{
    int i;

    (void)userdata;
    for (i = 0; i + 1 < length; i += 2) {
        Sint16 sample = ((phase++ % 50) < 25) ? 2048 : -2048;
        stream[i] = (Uint8)((sample >> 8) & 0xff);
        stream[i + 1] = (Uint8)(sample & 0xff);
    }
    if (i < length) stream[i] = 0;
    SDL_AtomicIncRef(&callback_count);
}

static int Fail(const char *what)
{
    fprintf(stdout, "openstep-sdl-physical-tone-probe: %s: %s\n", what, SDL_GetError());
    fflush(stdout);
    return 1;
}

int main(int argc, char **argv)
{
    SDL_AudioSpec want;
    SDL_AudioSpec have;
    SDL_AudioDeviceID device;
    int result = 0;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-physical-tone.log", "w", stdout)) {
        return 2;
    }
    if (SDL_setenv("SDL_AUDIODRIVER", "openstep", 1) != 0) return Fail("set audio driver");
    SDL_zero(want);
    want.freq = 22050;
    want.format = AUDIO_S16MSB;
    want.channels = 1;
    want.samples = 512;
    want.callback = FillTone;
    SDL_AtomicSet(&callback_count, 0);
    phase = 0;
    if (SDL_Init(SDL_INIT_AUDIO) != 0) return Fail("audio init");
    device = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (device == 0 || have.freq != 22050 || have.format != AUDIO_S16MSB ||
        have.channels != 1) {
        result = Fail("SoundKit device negotiation");
        goto done;
    }
    fprintf(stdout, "openstep-sdl-physical-tone-probe: PLAY 441Hz 60sec\n");
    fflush(stdout);
    SDL_PauseAudioDevice(device, 0);
    SDL_Delay(PLAY_MILLISECONDS);
    SDL_PauseAudioDevice(device, 1);
    if (SDL_AtomicGet(&callback_count) < 1) result = Fail("no audio callbacks");
    SDL_CloseAudioDevice(device);

done:
    SDL_Quit();
    if (result == 0) {
        fprintf(stdout, "openstep-sdl-physical-tone-probe: PASS callbacks=%d\n",
                SDL_AtomicGet(&callback_count));
    }
    fflush(stdout);
    return result;
}
