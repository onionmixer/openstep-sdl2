#include "SDL.h"
#include "SDL_loadso.h"
#include "SDL_filesystem.h"
#include "SDL_locale.h"
#include "SDL_power.h"
#include "SDL_internal.h"

int main(void)
{
    SDL_PowerState power;
    SDL_Locale *locales;
    int seconds = 0;
    int percent = 0;
    void *object;
    char *path;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(0) != 0) {
        return 1;
    }
    if (SDL_WasInit(0) != 0) {
        SDL_Quit();
        return 2;
    }

    power = SDL_GetPowerInfo(&seconds, &percent);
    if (power != SDL_POWERSTATE_UNKNOWN || seconds != -1 || percent != -1) {
        SDL_Quit();
        return 3;
    }
    path = SDL_GetBasePath();
    if (path != NULL) {
        SDL_free(path);
        SDL_Quit();
        return 4;
    }
    path = SDL_GetPrefPath("OpenStep", "SDL2");
    if (path != NULL) {
        SDL_free(path);
        SDL_Quit();
        return 5;
    }
    object = SDL_LoadObject("not-a-real-openstep-library");
    if (object != NULL) {
        SDL_UnloadObject(object);
        SDL_Quit();
        return 6;
    }
    locales = SDL_GetPreferredLocales();
    if (locales != NULL) {
        SDL_free(locales);
        SDL_Quit();
        return 7;
    }

    SDL_Quit();
    return 0;
}
