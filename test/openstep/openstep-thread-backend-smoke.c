#include "thread/SDL_thread_c.h"
#include "thread/SDL_systhread.h"

int SDL_SetError(const char *fmt, ...)
{
    (void)fmt;
    return -1;
}

int SDL_Error(SDL_errorcode code)
{
    (void)code;
    return -1;
}

void SDL_Delay(Uint32 ms)
{
    (void)ms;
}

void SDL_RunThread(SDL_Thread *thread)
{
    thread->threadid = SDL_ThreadID();
    thread->status = 41;
}

int main(void)
{
    SDL_Thread thread = { 0 };

    if (SDL_SYS_CreateThread(&thread) != 0) {
        return 1;
    }
    SDL_SYS_WaitThread(&thread);
    if (thread.status != 41 || thread.threadid == 0 ||
        thread.handle != NO_CTHREAD) {
        return 2;
    }
    return 0;
}
