/*
 * Bootstrap used only by the bounded OPENSTEP core compiler-gate archive.
 *
 * Whole src/SDL.c owns this symbol in the eventual complete library, but that
 * source currently dispatches unported video/audio/event subsystems. Keep this
 * file out of that later build and use it only for prototype validation.
 */
#include "../SDL_internal.h"

#include "../SDL_log_c.h"
#include "../thread/SDL_thread_c.h"
#include "../timer/SDL_timer_c.h"
#include "SDL_maincore.h"

static SDL_bool openstep_main_thread_initialized;

void SDL_InitMainThread(void)
{
    if (openstep_main_thread_initialized) {
        return;
    }
    SDL_InitTLSData();
    SDL_TicksInit();
    SDL_LogInit();
    openstep_main_thread_initialized = SDL_TRUE;
}

void SDL_OpenStepQuitCore(void)
{
    if (!openstep_main_thread_initialized) {
        return;
    }
    SDL_LogQuit();
    SDL_TicksQuit();
    SDL_QuitTLSData();
    openstep_main_thread_initialized = SDL_FALSE;
}
