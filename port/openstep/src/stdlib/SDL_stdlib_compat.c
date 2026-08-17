/* Minimal SDL stdinc wrappers required by the current OPENSTEP core subset. */
#include "../SDL_internal.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

int SDL_isdigit(int value)
{
    if (value == EOF) {
        return 0;
    }
    return isdigit((unsigned char)value);
}

int SDL_isspace(int value)
{
    if (value == EOF) {
        return 0;
    }
    return isspace((unsigned char)value);
}

int SDL_tolower(int value)
{
    if (value == EOF) {
        return EOF;
    }
    return tolower((unsigned char)value);
}

int SDL_toupper(int value)
{
    if (value == EOF) {
        return EOF;
    }
    return toupper((unsigned char)value);
}

void *SDL_memset(void *destination, int value, size_t length)
{
    return memset(destination, value, length);
}

void *SDL_memcpy(void *destination, const void *source, size_t length)
{
    return memcpy(destination, source, length);
}
