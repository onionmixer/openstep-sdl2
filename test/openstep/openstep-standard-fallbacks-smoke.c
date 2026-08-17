#include "SDL.h"
#include "thread/SDL_thread_c.h"

void SDL_InitMainThread(void)
{
    SDL_InitTLSData();
}

int main(void)
{
    SDL_PowerState power;
    SDL_Locale *locales;
    int seconds = 0;
    int percent = 0;
    void *object;
    char *path;

    /* This is performed by the real SDL.c dispatcher before subsystems use
       SDL_SetError() or hints. Keep this direct-subsystem smoke equivalent. */
    SDL_InitMainThread();
    power = SDL_GetPowerInfo(&seconds, &percent);
    if (power != SDL_POWERSTATE_UNKNOWN || seconds != -1 || percent != -1) {
        return 1;
    }
    path = SDL_GetBasePath();
    if (path != NULL) {
        SDL_free(path);
        return 2;
    }
    path = SDL_GetPrefPath("OpenStep", "SDL2");
    if (path != NULL) {
        SDL_free(path);
        return 3;
    }
    object = SDL_LoadObject("not-a-real-openstep-library");
    if (object != NULL) {
        SDL_UnloadObject(object);
        return 4;
    }
    locales = SDL_GetPreferredLocales();
    if (locales != NULL) {
        SDL_free(locales);
        return 5;
    }
    return 0;
}
