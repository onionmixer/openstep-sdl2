#include "SDL.h"

SDL_COMPILE_TIME_ASSERT(openstep_sint8_size, sizeof(Sint8) == 1);
SDL_COMPILE_TIME_ASSERT(openstep_uint8_size, sizeof(Uint8) == 1);
SDL_COMPILE_TIME_ASSERT(openstep_sint16_size, sizeof(Sint16) == 2);
SDL_COMPILE_TIME_ASSERT(openstep_uint16_size, sizeof(Uint16) == 2);
SDL_COMPILE_TIME_ASSERT(openstep_sint32_size, sizeof(Sint32) == 4);
SDL_COMPILE_TIME_ASSERT(openstep_uint32_size, sizeof(Uint32) == 4);
SDL_COMPILE_TIME_ASSERT(openstep_sint64_size, sizeof(Sint64) == 8);
SDL_COMPILE_TIME_ASSERT(openstep_uint64_size, sizeof(Uint64) == 8);
SDL_COMPILE_TIME_ASSERT(openstep_pointer_size, sizeof(uintptr_t) == sizeof(void *));

int main(int argc, char *argv[])
{
    SDL_version version;
    SDL_VERSION(&version);
    return (argc == 0 || argv == 0 || version.major != SDL_MAJOR_VERSION);
}

