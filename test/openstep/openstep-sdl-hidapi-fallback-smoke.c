/* Non-GUI proof that OPENSTEP uses SDL's standard disabled-HIDAPI semantics. */
#include "SDL.h"
#include "SDL_hidapi.h"
#include <stdio.h>

int main(int argc, char **argv)
{
    struct SDL_hid_device_info *devices;

    (void)argc;
    (void)argv;

    if (SDL_hid_init() != 0) {
        fprintf(stderr, "hidapi-smoke: SDL_hid_init failed: %s\n", SDL_GetError());
        return 1;
    }
    if (SDL_hid_device_change_count() != 0) return 2;
    devices = SDL_hid_enumerate(0, 0);
    if (devices != NULL) {
        SDL_hid_free_enumeration(devices);
        return 3;
    }
    if (SDL_hid_open(0, 0, NULL) != NULL) return 4;
    if (SDL_hid_open_path("/dev/no-such-hid", 0) != NULL) return 5;
    SDL_hid_ble_scan(SDL_TRUE);
    if (SDL_hid_exit() != 0) return 6;

    printf("openstep-sdl-hidapi-fallback-smoke: PASS standard disabled HIDAPI\n");
    return 0;
}
