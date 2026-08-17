#include "SDL.h"
#include "SDL_joystick.h"
#include "SDL_gamecontroller.h"
#include "SDL_haptic.h"
#include "SDL_internal.h"

int main(void)
{
    Uint32 requested = SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER | SDL_INIT_HAPTIC;
    Uint32 initialized;

    SDL_SetMainReady();
    SDL_InitMainThread();

    if (SDL_Init(requested) != 0) {
        return 1;
    }
    initialized = SDL_WasInit(requested | SDL_INIT_EVENTS);
    if ((initialized & (requested | SDL_INIT_EVENTS)) !=
        (requested | SDL_INIT_EVENTS)) {
        SDL_Quit();
        return 2;
    }
    if (SDL_NumJoysticks() != 0) {
        SDL_Quit();
        return 3;
    }
    if (SDL_NumHaptics() != 0) {
        SDL_Quit();
        return 4;
    }
    if (SDL_IsGameController(0) != SDL_FALSE) {
        SDL_Quit();
        return 5;
    }

    SDL_Quit();
    return 0;
}
