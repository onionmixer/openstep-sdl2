#include "SDL.h"
#include "SDL_atomic.h"
#include "SDL_audio.h"
#include "SDL_cpuinfo.h"
#include "SDL_events.h"
#include "SDL_hints.h"
#include "SDL_pixels.h"
#include "SDL_render.h"
#include "SDL_rwops.h"
#include "SDL_surface.h"
#include "SDL_thread.h"
#include "SDL_timer.h"
#include "SDL_internal.h"
#include "video/SDL_yuv_c.h"

static volatile int matrix2_audio_callbacks;

static void SDLCALL Matrix2AudioCallback(void *userdata, Uint8 *stream, int len)
{
    (void)userdata;
    ++matrix2_audio_callbacks;
    SDL_memset(stream, 0, (size_t)len);
}

static int SDLCALL Matrix2Thread(void *userdata)
{
    int *value = (int *)userdata;
    *value = 0x2468;
    return 0x1357;
}

static int Matrix2AudioCallbackPath(void)
{
    SDL_AudioSpec desired;
    SDL_AudioSpec obtained;
    SDL_AudioDeviceID device;

    SDL_zero(desired);
    matrix2_audio_callbacks = 0;
    desired.freq = 22050;
    desired.format = AUDIO_S16SYS;
    desired.channels = 1;
    desired.samples = 128;
    desired.callback = Matrix2AudioCallback;
    device = SDL_OpenAudioDevice(NULL, 0, &desired, &obtained, 0);
    if (device == 0 || obtained.channels != 1) {
        if (device != 0) SDL_CloseAudioDevice(device);
        return -1;
    }
    SDL_PauseAudioDevice(device, 0);
    SDL_Delay(40);
    SDL_PauseAudioDevice(device, 1);
    SDL_CloseAudioDevice(device);
    return matrix2_audio_callbacks > 0 ? 0 : -1;
}

static int Matrix2AudioQueuePath(void)
{
    SDL_AudioSpec desired;
    SDL_AudioDeviceID device;
    Uint8 samples[32];

    SDL_zero(desired);
    SDL_memset(samples, 0, sizeof(samples));
    desired.freq = 22050;
    desired.format = AUDIO_S16SYS;
    desired.channels = 1;
    desired.samples = 128;
    device = SDL_OpenAudioDevice(NULL, 0, &desired, NULL, 0);
    if (device == 0) {
        return -1;
    }
    if (SDL_QueueAudio(device, samples, (Uint32)sizeof(samples)) != 0 ||
        SDL_GetQueuedAudioSize(device) != sizeof(samples)) {
        SDL_CloseAudioDevice(device);
        return -1;
    }
    SDL_ClearQueuedAudio(device);
    if (SDL_GetQueuedAudioSize(device) != 0) {
        SDL_CloseAudioDevice(device);
        return -1;
    }
    SDL_CloseAudioDevice(device);
    return 0;
}

static int Matrix2Events(void)
{
    Uint32 type;
    SDL_Event event;
    SDL_Event received;

    type = SDL_RegisterEvents(1);
    if (type == (Uint32)-1) {
        return -1;
    }
    event.type = type;
    event.user.timestamp = 0;
    event.user.windowID = 0;
    event.user.code = 0x3333;
    event.user.data1 = NULL;
    event.user.data2 = NULL;
    if (SDL_PeepEvents(&event, 1, SDL_ADDEVENT, type, type) != 1 ||
        SDL_PeepEvents(&received, 1, SDL_GETEVENT, type, type) != 1 ||
        received.type != type || received.user.code != 0x3333) {
        return -1;
    }
    if (SDL_PeepEvents(&event, 1, SDL_ADDEVENT, type, type) != 1) {
        return -1;
    }
    SDL_FlushEvent(type);
    return SDL_PeepEvents(&received, 1, SDL_PEEKEVENT, type, type) == 0 ? 0 : -1;
}

static int Matrix2Hints(void)
{
    const char *name = "OPENSTEP_SDL20_MATRIX2";

    SDL_ResetHint(name);
    if (SDL_SetHintWithPriority(name, "low", SDL_HINT_DEFAULT) != SDL_TRUE ||
        SDL_SetHintWithPriority(name, "high", SDL_HINT_OVERRIDE) != SDL_TRUE ||
        SDL_SetHintWithPriority(name, "ignored", SDL_HINT_NORMAL) != SDL_FALSE ||
        SDL_GetHint(name) == NULL || SDL_strcmp(SDL_GetHint(name), "high") != 0) {
        SDL_ResetHint(name);
        return -1;
    }
    SDL_ResetHint(name);
    return 0;
}

static int Matrix2RWopsFile(void)
{
    const char *path = "/tmp/SDL20/build/runtime-matrix2-rwops.bin";
    Uint8 input[3];
    Uint8 output[3];
    SDL_RWops *rw;

    input[0] = 'N';
    input[1] = 'X';
    input[2] = 'T';
    rw = SDL_RWFromFile(path, "wb+");
    if (rw == NULL ||
        SDL_RWwrite(rw, input, 1, 3) != 3 ||
        SDL_RWseek(rw, 0, RW_SEEK_SET) != 0 ||
        SDL_RWread(rw, output, 1, 3) != 3 ||
        output[0] != 'N' || output[1] != 'X' || output[2] != 'T' ||
        SDL_RWclose(rw) != 0) {
        return -1;
    }
    return 0;
}

static int Matrix2ThreadPath(void)
{
    SDL_Thread *thread;
    int value = 0;
    int status = 0;

    thread = SDL_CreateThread(Matrix2Thread, "matrix2", &value);
    if (thread == NULL) {
        return -1;
    }
    SDL_WaitThread(thread, &status);
    return (value == 0x2468 && status == 0x1357) ? 0 : -1;
}

static int Matrix2CPU(void)
{
    return (SDL_GetCPUCount() >= 1 && SDL_SIMDGetAlignment() >= 4) ? 0 : -1;
}

static int Matrix2Renderer(void)
{
    SDL_Surface *surface;
    SDL_Renderer *renderer;
    SDL_Rect clip;
    SDL_Rect rect;
    Uint32 black;
    Uint32 green;
    Uint32 blue;
    Uint32 *pixels;

    surface = SDL_CreateRGBSurfaceWithFormat(0, 5, 5, 32,
                                             SDL_PIXELFORMAT_ARGB8888);
    if (surface == NULL) return -1;
    renderer = SDL_CreateSoftwareRenderer(surface);
    if (renderer == NULL) {
        SDL_FreeSurface(surface);
        return -1;
    }
    black = SDL_MapRGBA(surface->format, 0, 0, 0, 0xff);
    green = SDL_MapRGBA(surface->format, 0x10, 0xd0, 0x20, 0xff);
    blue = SDL_MapRGBA(surface->format, 0x20, 0x40, 0xe0, 0xff);
    clip.x = 1;
    clip.y = 1;
    clip.w = 2;
    clip.h = 2;
    rect.x = 0;
    rect.y = 0;
    rect.w = 1;
    rect.h = 1;
    if (SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 ||
        SDL_RenderSetClipRect(renderer, &clip) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0x10, 0xd0, 0x20, 0xff) != 0 ||
        SDL_RenderDrawLine(renderer, 0, 0, 4, 4) != 0 ||
        SDL_RenderFlush(renderer) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    pixels = (Uint32 *)surface->pixels;
    if (pixels[0] != black ||
        pixels[(surface->pitch / (int)sizeof(Uint32)) + 1] != green ||
        pixels[3 * (surface->pitch / (int)sizeof(Uint32)) + 3] != black) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    if (SDL_RenderSetClipRect(renderer, NULL) != 0 ||
        SDL_RenderSetScale(renderer, 2.0f, 2.0f) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0x20, 0x40, 0xe0, 0xff) != 0 ||
        SDL_RenderFillRect(renderer, &rect) != 0 ||
        SDL_RenderFlush(renderer) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    if (pixels[0] != blue ||
        pixels[(surface->pitch / (int)sizeof(Uint32)) + 1] != blue) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    SDL_DestroyRenderer(renderer);
    SDL_FreeSurface(surface);
    return 0;
}

static int Matrix2NV12(void)
{
    Uint8 nv12[6];
    Uint32 argb[4];
    size_t size;
    int pitch;

    if (SDL_CalculateYUVSize(SDL_PIXELFORMAT_NV12, 2, 2, &size, &pitch) != 0 ||
        size != 6 || pitch != 2) return -1;
    nv12[0] = 235;
    nv12[1] = 235;
    nv12[2] = 235;
    nv12[3] = 235;
    nv12[4] = 128;
    nv12[5] = 128;
    return SDL_ConvertPixels(2, 2, SDL_PIXELFORMAT_NV12, nv12, pitch,
                             SDL_PIXELFORMAT_ARGB8888, argb,
                             2 * (int)sizeof(Uint32));
}

int main(void)
{
    const char *audio_driver;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_EVENTS | SDL_INIT_TIMER | SDL_INIT_AUDIO) != 0) return 1;
    audio_driver = SDL_GetCurrentAudioDriver();
    if (audio_driver == NULL || SDL_strcmp(audio_driver, "dummy") != 0) { SDL_Quit(); return 2; }
    if (Matrix2AudioCallbackPath() != 0) { SDL_Quit(); return 3; }
    if (Matrix2AudioQueuePath() != 0) { SDL_Quit(); return 4; }
    if (Matrix2Events() != 0) { SDL_Quit(); return 5; }
    if (Matrix2Hints() != 0) { SDL_Quit(); return 6; }
    if (Matrix2RWopsFile() != 0) { SDL_Quit(); return 7; }
    if (Matrix2ThreadPath() != 0) { SDL_Quit(); return 8; }
    if (Matrix2CPU() != 0) { SDL_Quit(); return 9; }
    if (Matrix2Renderer() != 0) { SDL_Quit(); return 10; }
    if (Matrix2NV12() != 0) { SDL_Quit(); return 11; }
    SDL_Quit();
    return 0;
}
