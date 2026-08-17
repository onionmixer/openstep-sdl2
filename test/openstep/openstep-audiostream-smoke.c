/* Exercise SDL2's real stream conversion boundary used by the SoundKit
   backend: the i486 application's native S16LSB PCM must become SoundKit's
   S16MSB LINEAR_16 PCM through SDL's common audio code. */
#include "SDL_audio.h"
#include "thread/SDL_thread_c.h"

void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

int main(void)
{
    SDL_AudioStream *stream;
    Uint8 source[8];
    Uint8 target[8];
    int available;
    int received;

    source[0] = 0x34;
    source[1] = 0x12;
    source[2] = 0xcd;
    source[3] = 0xab;
    source[4] = 0x00;
    source[5] = 0x80;
    source[6] = 0xff;
    source[7] = 0x7f;

    stream = SDL_NewAudioStream(AUDIO_S16LSB, 1, 22050,
                                AUDIO_S16MSB, 1, 22050);
    if (stream == NULL) {
        return 1;
    }
    if (SDL_AudioStreamPut(stream, source, sizeof(source)) != 0 ||
        SDL_AudioStreamFlush(stream) != 0) {
        SDL_FreeAudioStream(stream);
        return 2;
    }
    available = SDL_AudioStreamAvailable(stream);
    if (available != (int)sizeof(target)) {
        SDL_FreeAudioStream(stream);
        return 3;
    }
    received = SDL_AudioStreamGet(stream, target, sizeof(target));
    if (received != (int)sizeof(target) ||
        target[0] != 0x12 || target[1] != 0x34 ||
        target[2] != 0xab || target[3] != 0xcd ||
        target[4] != 0x80 || target[5] != 0x00 ||
        target[6] != 0x7f || target[7] != 0xff ||
        SDL_AudioStreamAvailable(stream) != 0) {
        SDL_FreeAudioStream(stream);
        return 4;
    }
    SDL_FreeAudioStream(stream);
    return 0;
}
