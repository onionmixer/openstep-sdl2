/*
 * Preprocessor-only public runtime header audit input.
 *
 * SDL.h intentionally does not include the opt-in SDL_syswm.h and
 * SDL_vulkan.h headers, although their ordinary SDL exports belong to the
 * SDL2 runtime ABI.  SDL_test*.h is deliberately absent: it is upstream test
 * support, not part of libSDL2's runtime-library contract.  SDL OpenGL and
 * GLES headers are also absent because they declare the external GL APIs,
 * not symbols supplied by libSDL2.
 */
#include "SDL.h"
#include "SDL_syswm.h"
#include "SDL_vulkan.h"
