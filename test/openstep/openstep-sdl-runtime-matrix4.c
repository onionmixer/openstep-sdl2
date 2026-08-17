#include "SDL.h"
#include "SDL_events.h"
#include "SDL_filesystem.h"
#include "SDL_haptic.h"
#include "SDL_joystick.h"
#include "SDL_locale.h"
#include "SDL_misc.h"
#include "SDL_pixels.h"
#include "SDL_power.h"
#include "SDL_render.h"
#include "SDL_rwops.h"
#include "SDL_sensor.h"
#include "SDL_timer.h"
#include "SDL_internal.h"

static int matrix4_log_calls;

static void SDLCALL Matrix4LogOutput(void *userdata, int category,
                                     SDL_LogPriority priority, const char *message)
{
    (void)userdata;
    (void)category;
    (void)priority;
    if (message != NULL) ++matrix4_log_calls;
}

static int Matrix4Version(void)
{
    SDL_version version;

    SDL_GetVersion(&version);
    return (version.major == SDL_MAJOR_VERSION &&
            version.minor == SDL_MINOR_VERSION &&
            version.patch == SDL_PATCHLEVEL &&
            SDL_GetRevision() != NULL && SDL_GetPlatform() != NULL) ? 0 : -1;
}

static int Matrix4LogAndError(void)
{
    matrix4_log_calls = 0;
    SDL_LogSetOutputFunction(Matrix4LogOutput, NULL);
    SDL_Log("matrix4 log probe");
    if (matrix4_log_calls != 1 || SDL_OpenURL(NULL) == 0 || SDL_GetError()[0] == '\0') {
        SDL_LogSetOutputFunction(NULL, NULL);
        return -1;
    }
    SDL_ClearError();
    SDL_LogSetOutputFunction(NULL, NULL);
    return SDL_GetError()[0] == '\0' ? 0 : -1;
}

static int Matrix4Time(void)
{
    Uint64 frequency;
    Uint64 before;
    Uint64 after;

    frequency = SDL_GetPerformanceFrequency();
    before = SDL_GetPerformanceCounter();
    SDL_Delay(5);
    after = SDL_GetPerformanceCounter();
    return (frequency > 0 && after >= before && SDL_GetTicks64() >= 5) ? 0 : -1;
}

static int Matrix4RenderDrivers(void)
{
    SDL_RendererInfo info;

    if (SDL_GetNumRenderDrivers() < 1 || SDL_GetRenderDriverInfo(0, &info) != 0 ||
        info.name == NULL) return -1;
    return 0;
}

static int Matrix4Pixels(void)
{
    int bpp;
    Uint32 rmask, gmask, bmask, amask;
    Uint32 format;

    if (SDL_PixelFormatEnumToMasks(SDL_PIXELFORMAT_ARGB8888, &bpp,
                                   &rmask, &gmask, &bmask, &amask) != SDL_TRUE ||
        bpp != 32) return -1;
    format = SDL_MasksToPixelFormatEnum(bpp, rmask, gmask, bmask, amask);
    return format == SDL_PIXELFORMAT_ARGB8888 ? 0 : -1;
}

static int Matrix4RWopsConst(void)
{
    Uint8 output[3];
    SDL_RWops *rw;

    rw = SDL_RWFromConstMem("abc", 3);
    if (rw == NULL || SDL_RWread(rw, output, 1, 3) != 3 ||
        output[0] != 'a' || output[1] != 'b' || output[2] != 'c' ||
        SDL_RWwrite(rw, "x", 1, 1) != 0 || SDL_RWclose(rw) != 0) {
        return -1;
    }
    return 0;
}

static int Matrix4NoDeviceInput(void)
{
    return (SDL_NumJoysticks() == 0 && SDL_NumHaptics() == 0 && SDL_NumSensors() == 0 &&
            SDL_JoystickOpen(0) == NULL && SDL_HapticOpen(0) == NULL &&
            SDL_SensorOpen(0) == NULL) ? 0 : -1;
}

static int Matrix4Fallbacks(void)
{
    SDL_PowerState power;
    SDL_Locale *locales;
    int seconds = 0;
    int percent = 0;
    char *path;

    power = SDL_GetPowerInfo(&seconds, &percent);
    path = SDL_GetBasePath();
    locales = SDL_GetPreferredLocales();
    if (path != NULL) SDL_free(path);
    if (locales != NULL) SDL_free(locales);
    return (power == SDL_POWERSTATE_UNKNOWN && seconds == -1 && percent == -1 &&
            path == NULL && locales == NULL) ? 0 : -1;
}

static int Matrix4EventState(void)
{
    SDL_Event event;

    if (SDL_HasEvent(SDL_USEREVENT) != SDL_FALSE) return -1;
    SDL_FlushEvents(SDL_USEREVENT, SDL_LASTEVENT);
    return SDL_PollEvent(&event) == 0 ? 0 : -1;
}

int main(void)
{
    Uint32 init_flags = SDL_INIT_EVENTS | SDL_INIT_JOYSTICK | SDL_INIT_HAPTIC | SDL_INIT_SENSOR;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(init_flags) != 0) return 1;
    if (Matrix4Version() != 0) { SDL_Quit(); return 2; }
    if (Matrix4LogAndError() != 0) { SDL_Quit(); return 3; }
    if (Matrix4Time() != 0) { SDL_Quit(); return 4; }
    if (Matrix4RenderDrivers() != 0) { SDL_Quit(); return 5; }
    if (Matrix4Pixels() != 0) { SDL_Quit(); return 6; }
    if (Matrix4RWopsConst() != 0) { SDL_Quit(); return 7; }
    if (Matrix4NoDeviceInput() != 0) { SDL_Quit(); return 8; }
    if (Matrix4Fallbacks() != 0) { SDL_Quit(); return 9; }
    if (Matrix4EventState() != 0) { SDL_Quit(); return 10; }
    SDL_Quit();
    return 0;
}
