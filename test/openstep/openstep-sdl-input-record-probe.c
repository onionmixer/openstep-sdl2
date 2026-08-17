/* Direct-GCD interactive SDL input probe with a target-local record. The
   program redirects only its own stdout; it must be launched directly, not
   through a shell wrapper, so it retains the console AppKit session. */
#include <stdio.h>

#include "SDL.h"

static void
print_event(const SDL_Event *event)
{
    switch (event->type) {
    case SDL_KEYDOWN:
    case SDL_KEYUP:
        printf("SDL key %s scancode=%d sym=%d mod=0x%04x repeat=%u\n",
               event->type == SDL_KEYDOWN ? "down" : "up",
               (int)event->key.keysym.scancode, (int)event->key.keysym.sym,
               (unsigned int)event->key.keysym.mod, (unsigned int)event->key.repeat);
        break;
    case SDL_TEXTINPUT:
        printf("SDL text %s\n", event->text.text);
        break;
    case SDL_MOUSEBUTTONDOWN:
    case SDL_MOUSEBUTTONUP:
        printf("SDL mouse %s button=%u x=%d y=%d\n",
               event->type == SDL_MOUSEBUTTONDOWN ? "down" : "up",
               (unsigned int)event->button.button, event->button.x, event->button.y);
        break;
    case SDL_MOUSEMOTION:
        printf("SDL mouse motion x=%d y=%d xrel=%d yrel=%d state=0x%x\n",
               event->motion.x, event->motion.y,
               event->motion.xrel, event->motion.yrel,
               (unsigned int)event->motion.state);
        break;
    case SDL_WINDOWEVENT:
        printf("SDL window event=%u data=%d,%d\n", (unsigned int)event->window.event,
               event->window.data1, event->window.data2);
        break;
    default:
        printf("SDL event type=0x%x\n", (unsigned int)event->type);
        break;
    }
    fflush(stdout);
}

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Event event;
    int running = 1;

    (void)argc;
    (void)argv;
    if (!freopen("/tmp/SDL20/log/openstep-sdl-input-record.log", "w", stdout)) {
        return 1;
    }
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stdout, "input record init failed: %s\n", SDL_GetError());
        return 2;
    }
    window = SDL_CreateWindow("SDL2 OPENSTEP input record -- Escape or close",
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              480, 180, SDL_WINDOW_RESIZABLE);
    if (!window) {
        fprintf(stdout, "input record window failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 3;
    }
    printf("SDL input record ready\n");
    fflush(stdout);
    /* Keep this physical-input probe on screen until the operator presses
       Escape or closes its window.  No idle timeout is used: physical input
       coverage is operator-paced and an ordinary SDL application may wait
       indefinitely for the next native event. */
    while (running) {
        if (!SDL_WaitEvent(&event)) {
            continue;
        }
        print_event(&event);
        if (event.type == SDL_QUIT ||
            (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE) ||
            (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)) {
            running = 0;
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-input-record-probe: PASS\n");
    return 0;
}
