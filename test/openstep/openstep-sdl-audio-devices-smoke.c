/* Verify the public SDL audio-device enumeration contract of the OPENSTEP
   SoundKit output backend: one default output device and no capture device. */
#include "SDL.h"
#include "SDL_internal.h"
#include <stdio.h>

int main(void)
{
    const char *output_name;
    SDL_AudioSpec desired;
    SDL_AudioDeviceID capture;
    int result = 0;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_AUDIO) != 0) return 1;
    if (SDL_GetNumAudioDevices(0) != 1) {
        result = 2;
        goto done;
    }
    output_name = SDL_GetAudioDeviceName(0, 0);
    if (!output_name || !output_name[0]) {
        result = 3;
        goto done;
    }
    if (SDL_GetNumAudioDevices(1) != 0) {
        result = 4;
        goto done;
    }
    SDL_ClearError();
    if (SDL_GetAudioDeviceName(0, 1) != NULL || SDL_GetError()[0] == '\0') {
        result = 5;
        goto done;
    }
    SDL_zero(desired);
    desired.freq = 22050;
    desired.format = AUDIO_S16MSB;
    desired.channels = 1;
    desired.samples = 512;
    SDL_ClearError();
    capture = SDL_OpenAudioDevice(NULL, 1, &desired, NULL, 0);
    if (capture != 0 || SDL_GetError()[0] == '\0') {
        result = 6;
        goto done;
    }

done:
    SDL_Quit();
    if (result) {
        fprintf(stderr, "openstep-sdl-audio-devices-smoke: failed checkpoint %d\n", result);
        return result;
    }
    printf("openstep-sdl-audio-devices-smoke: PASS default output and no capture\n");
    return 0;
}
