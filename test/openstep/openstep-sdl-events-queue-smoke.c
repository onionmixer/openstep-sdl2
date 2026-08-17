#include "SDL.h"
#include "SDL_events.h"
#include "SDL_internal.h"

int main(void)
{
    SDL_Event event;
    SDL_Event received;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_EVENTS) != 0) {
        return 1;
    }
    if ((SDL_WasInit(SDL_INIT_EVENTS) & SDL_INIT_EVENTS) == 0) {
        SDL_Quit();
        return 2;
    }

    event.type = SDL_USEREVENT;
    event.user.timestamp = 0;
    event.user.windowID = 0;
    event.user.code = 0x1234;
    event.user.data1 = NULL;
    event.user.data2 = NULL;
    if (SDL_PushEvent(&event) != 1) {
        SDL_Quit();
        return 3;
    }
    if (SDL_PollEvent(&received) != 1 ||
        received.type != SDL_USEREVENT || received.user.code != 0x1234) {
        SDL_Quit();
        return 4;
    }
    if (SDL_PollEvent(&received) != 0) {
        SDL_Quit();
        return 5;
    }

    SDL_Quit();
    return 0;
}
