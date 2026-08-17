/* Standard SDL2 native SoundKit output smoke for OPENSTEP. */
#include <stdio.h>

#include "SDL.h"

static SDL_atomic_t callback_count;

static void SDLCALL
fill_silence(void *userdata, Uint8 *stream, int length)
{
    (void)userdata;
    SDL_memset(stream, 0, (size_t)length);
    SDL_AtomicIncRef(&callback_count);
}

static void
checkpoint(const char *name)
{
    fprintf(stderr, "openstep-sdl-soundkit-smoke: %s\n", name);
    fflush(stderr);
}

int
main(int argc, char **argv)
{
    SDL_AudioSpec want;
    SDL_AudioSpec have;
    SDL_AudioDeviceID device;

    (void)argc;
    (void)argv;
    SDL_zero(want);
    want.freq = 22050;
    want.format = AUDIO_S16MSB;
    want.channels = 1;
    want.samples = 512;
    want.callback = fill_silence;
    SDL_AtomicSet(&callback_count, 0);
    checkpoint("SDL_Init(SDL_INIT_AUDIO)");
    if (SDL_Init(SDL_INIT_AUDIO) != 0) goto failed;
    checkpoint("SDL_OpenAudioDevice native SoundKit");
    device = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);
    if (device == 0 || have.format != AUDIO_S16MSB ||
        have.freq != 22050 || have.channels != 1) goto failed_quit;
    checkpoint("resume callback delivery");
    SDL_PauseAudioDevice(device, 0);
    SDL_Delay(600);
    if (SDL_AtomicGet(&callback_count) < 1) goto failed_device;
    checkpoint("pause resume and close drain");
    SDL_PauseAudioDevice(device, 1);
    SDL_Delay(20);
    SDL_PauseAudioDevice(device, 0);
    SDL_Delay(300);
    SDL_CloseAudioDevice(device);
    SDL_Quit();
    printf("openstep-sdl-soundkit-smoke: PASS callbacks=%d\n",
           SDL_AtomicGet(&callback_count));
    return 0;

failed_device:
    SDL_CloseAudioDevice(device);
failed_quit:
    SDL_Quit();
failed:
    fprintf(stderr, "openstep SoundKit smoke failed: %s\n", SDL_GetError());
    return 1;
}
