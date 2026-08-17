#include "SDL.h"
#include "SDL_misc.h"
#include "SDL_internal.h"

int main(void)
{
    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(0) != 0) {
        return 1;
    }
    if (SDL_OpenURL("https://example.invalid/") == 0) {
        SDL_Quit();
        return 2;
    }
    if (SDL_OpenURL(NULL) == 0) {
        SDL_Quit();
        return 3;
    }
    SDL_Quit();
    return 0;
}
