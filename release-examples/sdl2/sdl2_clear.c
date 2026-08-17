/* Source-only SDL2 2D example shipped in OpenStepSDL2Headers.pkg. */
#include <SDL2/SDL.h>

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Renderer *renderer;
    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) return 1;
    window = SDL_CreateWindow("OPENSTEP SDL2", SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED, 320, 200, 0);
    if (window == NULL) return 2;
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (renderer == NULL) return 3;
    SDL_SetRenderDrawColor(renderer, 0, 160, 0, 255);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);
    SDL_Delay(2000);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
