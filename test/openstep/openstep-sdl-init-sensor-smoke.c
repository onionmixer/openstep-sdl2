#include "SDL.h"
#include "SDL_sensor.h"
#include "SDL_internal.h"

int main(void)
{
    Uint32 initialized;

    SDL_SetMainReady();
    SDL_InitMainThread();

    if (SDL_Init(SDL_INIT_SENSOR) != 0) {
        return 1;
    }
    initialized = SDL_WasInit(SDL_INIT_SENSOR | SDL_INIT_EVENTS);
    if ((initialized & (SDL_INIT_SENSOR | SDL_INIT_EVENTS)) !=
        (SDL_INIT_SENSOR | SDL_INIT_EVENTS)) {
        SDL_Quit();
        return 2;
    }
    if (SDL_NumSensors() != 0) {
        SDL_Quit();
        return 3;
    }

    SDL_Quit();
    return 0;
}
