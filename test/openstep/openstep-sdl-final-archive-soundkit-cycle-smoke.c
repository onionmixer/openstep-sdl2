/* Repeat native SoundKit public-device lifecycle through final libSDL2.a.
   The callback writes silence, so this is safe to run without observing or
   interacting with the OPENSTEP screen or speakers. */
#include <stdio.h>

#include "SDL.h"

static SDL_atomic_t callback_count;

static void SDLCALL FillSilence(void *userdata, Uint8 *stream, int length)
{
    (void)userdata;
    SDL_memset(stream, 0, (size_t)length);
    SDL_AtomicIncRef(&callback_count);
}

static int RunCycle(int cycle)
{
    SDL_AudioSpec want;
    SDL_AudioSpec have;
    SDL_AudioDeviceID device;
    int before;
    int tries;

    SDL_zero(want);
    want.freq = 22050;
    want.format = AUDIO_S16MSB;
    want.channels = 1;
    want.samples = 512;
    want.callback = FillSilence;
    device = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (device == 0 || have.format != AUDIO_S16MSB || have.freq != 22050 ||
        have.channels != 1) {
        return 10 + cycle;
    }
    if (SDL_GetAudioDeviceStatus(device) != SDL_AUDIO_PAUSED) {
        SDL_CloseAudioDevice(device);
        return 20 + cycle;
    }
    before = SDL_AtomicGet(&callback_count);
    SDL_PauseAudioDevice(device, 0);
    for (tries = 0; tries < 20 && SDL_AtomicGet(&callback_count) == before; ++tries) {
        SDL_Delay(50);
    }
    if (SDL_GetAudioDeviceStatus(device) != SDL_AUDIO_PLAYING ||
        SDL_AtomicGet(&callback_count) == before) {
        SDL_CloseAudioDevice(device);
        return 30 + cycle;
    }
    SDL_PauseAudioDevice(device, 1);
    if (SDL_GetAudioDeviceStatus(device) != SDL_AUDIO_PAUSED) {
        SDL_CloseAudioDevice(device);
        return 40 + cycle;
    }
    SDL_Delay(40);
    before = SDL_AtomicGet(&callback_count);
    SDL_PauseAudioDevice(device, 0);
    for (tries = 0; tries < 20 && SDL_AtomicGet(&callback_count) == before; ++tries) {
        SDL_Delay(50);
    }
    if (SDL_AtomicGet(&callback_count) == before) {
        SDL_CloseAudioDevice(device);
        return 50 + cycle;
    }
    SDL_CloseAudioDevice(device);
    return 0;
}

int main(void)
{
    int cycle;
    int result = 0;

    if (SDL_setenv("SDL_AUDIODRIVER", "openstep", 1) != 0) return 1;
    SDL_AtomicSet(&callback_count, 0);
    if (SDL_Init(SDL_INIT_AUDIO) != 0) return 2;
    if (SDL_GetCurrentAudioDriver() == NULL ||
        SDL_strcmp(SDL_GetCurrentAudioDriver(), "openstep") != 0) {
        result = 3;
    } else {
        for (cycle = 0; cycle < 3; ++cycle) {
            result = RunCycle(cycle);
            if (result != 0) break;
        }
    }
    SDL_Quit();
    if (result != 0) {
        fprintf(stderr, "openstep-sdl-final-archive-soundkit-cycle-smoke: failed checkpoint %d: %s\n",
                result, SDL_GetError());
        return result;
    }
    printf("openstep-sdl-final-archive-soundkit-cycle-smoke: PASS cycles=3 callbacks=%d\n",
           SDL_AtomicGet(&callback_count));
    return 0;
}
