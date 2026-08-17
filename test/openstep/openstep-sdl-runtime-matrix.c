#include "SDL.h"
#include "SDL_audio.h"
#include "SDL_events.h"
#include "SDL_joystick.h"
#include "SDL_pixels.h"
#include "SDL_render.h"
#include "SDL_rwops.h"
#include "SDL_surface.h"
#include "SDL_timer.h"
#include "SDL_internal.h"
#include "video/SDL_yuv_c.h"

static int matrix_filter_hits;
static int matrix_watch_hits;
static int matrix_timer_hits;

static void SDLCALL MatrixHintCallback(void *userdata, const char *name,
                                       const char *old_value, const char *value)
{
    int *hits = (int *)userdata;
    (void)name;
    (void)old_value;
    (void)value;
    ++*hits;
}

static int SDLCALL MatrixEventFilter(void *userdata, SDL_Event *event)
{
    (void)userdata;
    if (event->type == SDL_USEREVENT) {
        ++matrix_filter_hits;
    }
    return 1;
}

static int SDLCALL MatrixEventWatch(void *userdata, SDL_Event *event)
{
    (void)userdata;
    if (event->type == SDL_USEREVENT) {
        ++matrix_watch_hits;
    }
    return 0;
}

static Uint32 SDLCALL MatrixTimer(Uint32 interval, void *userdata)
{
    (void)interval;
    (void)userdata;
    ++matrix_timer_hits;
    return 0;
}

static int MatrixHint(void)
{
    int hits = 0;

    SDL_AddHintCallback("OPENSTEP_SDL20_MATRIX", MatrixHintCallback, &hits);
    if (SDL_SetHint("OPENSTEP_SDL20_MATRIX", "one") != SDL_TRUE ||
        SDL_SetHint("OPENSTEP_SDL20_MATRIX", "two") != SDL_TRUE ||
        SDL_GetHint("OPENSTEP_SDL20_MATRIX") == NULL ||
        SDL_strcmp(SDL_GetHint("OPENSTEP_SDL20_MATRIX"), "two") != 0 ||
        hits < 3) {
        SDL_DelHintCallback("OPENSTEP_SDL20_MATRIX", MatrixHintCallback, &hits);
        return -1;
    }
    SDL_DelHintCallback("OPENSTEP_SDL20_MATRIX", MatrixHintCallback, &hits);
    SDL_ResetHint("OPENSTEP_SDL20_MATRIX");
    return 0;
}

static int MatrixRWops(void)
{
    Uint8 buffer[8];
    Uint8 result[2];
    SDL_RWops *rw;

    rw = SDL_RWFromMem(buffer, (int)sizeof(buffer));
    if (rw == NULL ||
        SDL_RWwrite(rw, "OS", 1, 2) != 2 ||
        SDL_RWseek(rw, 0, RW_SEEK_SET) != 0 ||
        SDL_RWread(rw, result, 1, 2) != 2 ||
        result[0] != 'O' || result[1] != 'S' ||
        SDL_RWclose(rw) != 0) {
        return -1;
    }
    return 0;
}

static int MatrixGUID(void)
{
    SDL_JoystickGUID guid;
    char text[33];

    guid = SDL_JoystickGetGUIDFromString("03000000000000000000000000000000");
    SDL_JoystickGetGUIDString(guid, text, (int)sizeof(text));
    if (SDL_strlen(text) != 32 || SDL_strncmp(text, "03000000", 8) != 0) {
        return -1;
    }
    return 0;
}

static int MatrixEvents(void)
{
    SDL_Event event;
    SDL_Event received;

    matrix_filter_hits = 0;
    matrix_watch_hits = 0;
    SDL_SetEventFilter(MatrixEventFilter, NULL);
    SDL_AddEventWatch(MatrixEventWatch, NULL);
    event.type = SDL_USEREVENT;
    event.user.timestamp = 0;
    event.user.windowID = 0;
    event.user.code = 0x5678;
    event.user.data1 = NULL;
    event.user.data2 = NULL;
    if (SDL_PushEvent(&event) != 1 ||
        SDL_PollEvent(&received) != 1 ||
        received.user.code != 0x5678 ||
        matrix_filter_hits != 1 || matrix_watch_hits != 1) {
        SDL_DelEventWatch(MatrixEventWatch, NULL);
        SDL_SetEventFilter(NULL, NULL);
        return -1;
    }
    SDL_DelEventWatch(MatrixEventWatch, NULL);
    SDL_SetEventFilter(NULL, NULL);
    if (SDL_WaitEventTimeout(&received, 5) != 0) {
        return -1;
    }
    return 0;
}

static int MatrixTimerPath(void)
{
    SDL_TimerID timer;

    matrix_timer_hits = 0;
    timer = SDL_AddTimer(5, MatrixTimer, NULL);
    if (timer == 0) {
        return -1;
    }
    SDL_Delay(25);
    if (matrix_timer_hits != 1) {
        SDL_RemoveTimer(timer);
        return -1;
    }
    return 0;
}

static int MatrixRenderer(void)
{
    SDL_Surface *surface;
    SDL_Renderer *renderer;
    SDL_Rect viewport;
    Uint32 red;
    Uint32 black;
    Uint32 readback[4];
    Uint32 *pixels;

    surface = SDL_CreateRGBSurfaceWithFormat(0, 4, 4, 32,
                                             SDL_PIXELFORMAT_ARGB8888);
    if (surface == NULL) {
        return -1;
    }
    renderer = SDL_CreateSoftwareRenderer(surface);
    if (renderer == NULL) {
        SDL_FreeSurface(surface);
        return -1;
    }
    viewport.x = 1;
    viewport.y = 1;
    viewport.w = 2;
    viewport.h = 2;
    red = SDL_MapRGBA(surface->format, 0xe0, 0x20, 0x10, 0xff);
    black = SDL_MapRGBA(surface->format, 0, 0, 0, 0xff);
    if (SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 ||
        SDL_RenderSetViewport(renderer, &viewport) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0xe0, 0x20, 0x10, 0xff) != 0 ||
        SDL_RenderFillRect(renderer, NULL) != 0 ||
        SDL_RenderFlush(renderer) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    pixels = (Uint32 *)surface->pixels;
    if (pixels[0] != black ||
        pixels[(surface->pitch / (int)sizeof(Uint32)) + 1] != red ||
        pixels[2 * (surface->pitch / (int)sizeof(Uint32)) + 2] != red) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    if (SDL_RenderReadPixels(renderer, NULL, SDL_PIXELFORMAT_ARGB8888,
                             readback, 2 * (int)sizeof(Uint32)) != 0 ||
        readback[0] != red || readback[3] != red) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        return -1;
    }
    SDL_DestroyRenderer(renderer);
    SDL_FreeSurface(surface);
    return 0;
}

static int MatrixYUV(void)
{
    Uint8 iyuv[6];
    Uint32 argb[4];
    size_t size;
    int pitch;

    if (SDL_CalculateYUVSize(SDL_PIXELFORMAT_IYUV, 2, 2, &size, &pitch) != 0 ||
        size != 6 || pitch != 2) {
        return -1;
    }
    iyuv[0] = 235;
    iyuv[1] = 235;
    iyuv[2] = 235;
    iyuv[3] = 235;
    iyuv[4] = 128;
    iyuv[5] = 128;
    if (SDL_ConvertPixels(2, 2, SDL_PIXELFORMAT_IYUV, iyuv, pitch,
                          SDL_PIXELFORMAT_ARGB8888, argb,
                          2 * (int)sizeof(Uint32)) != 0) {
        return -1;
    }
    return 0;
}

int main(void)
{
    const char *audio_driver;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_EVENTS | SDL_INIT_TIMER | SDL_INIT_AUDIO) != 0) {
        return 1;
    }
    audio_driver = SDL_GetCurrentAudioDriver();
    if (audio_driver == NULL || SDL_strcmp(audio_driver, "dummy") != 0) {
        SDL_Quit();
        return 2;
    }
    if (MatrixHint() != 0) {
        SDL_Quit();
        return 3;
    }
    if (MatrixRWops() != 0) {
        SDL_Quit();
        return 4;
    }
    if (MatrixGUID() != 0) {
        SDL_Quit();
        return 5;
    }
    if (MatrixEvents() != 0) {
        SDL_Quit();
        return 6;
    }
    if (MatrixTimerPath() != 0) {
        SDL_Quit();
        return 7;
    }
    if (MatrixRenderer() != 0) {
        SDL_Quit();
        return 8;
    }
    if (MatrixYUV() != 0) {
        SDL_Quit();
        return 9;
    }
    SDL_Quit();
    return 0;
}
