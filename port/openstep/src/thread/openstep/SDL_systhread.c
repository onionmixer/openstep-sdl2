#include "../../SDL_internal.h"

#include <mach/cthreads.h>
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_interface.h>
#include <mach/thread_info.h>

#include "SDL_thread.h"
#include "../SDL_thread_c.h"
#include "../SDL_systhread.h"

static SDL_SpinLock openstep_cthreads_init_lock;
static int openstep_cthreads_initialized;

static any_t OpenStep_RunThread(any_t data)
{
    SDL_RunThread((SDL_Thread *)data);
    return (any_t)0;
}

int SDL_SYS_CreateThread(SDL_Thread *thread)
{
    cthread_t handle;

    if (thread->stacksize != 0) {
        return SDL_SetError("OPENSTEP cthreads has no requested stack-size API");
    }

    SDL_AtomicLock(&openstep_cthreads_init_lock);
    if (!openstep_cthreads_initialized) {
        cthread_init();
        openstep_cthreads_initialized = 1;
    }
    SDL_AtomicUnlock(&openstep_cthreads_init_lock);

    handle = cthread_fork((cthread_fn_t)OpenStep_RunThread, (any_t)thread);
    if (handle == NO_CTHREAD) {
        return SDL_SetError("cthread_fork failed");
    }
    thread->handle = handle;
    return 0;
}

void SDL_SYS_SetupThread(const char *name)
{
    cthread_t current;

    /* cthreads exposes a documented per-thread diagnostic name.  SDL calls
       this only from the newly created thread, so name the current cthread
       rather than relying on a parent-side race after cthread_fork(). */
    if (name == NULL || *name == '\0') return;
    current = cthread_self();
    if (current != NO_CTHREAD) {
        cthread_set_name(current, name);
    }
}

SDL_threadID SDL_ThreadID(void)
{
    return (SDL_threadID)(unsigned long)cthread_self();
}

/* SDL_audio.c asks for TIME_CRITICAL on the mixing thread the moment it
 * starts, and until now this port answered SDL_Unsupported() and left it at
 * whatever the task handed down.  That matters here more than on most
 * systems: NeXT Mach's default policy is timesharing, and its own
 * documentation says "a thread's priority gets lower as it runs (it ages)",
 * so the one thread in the process that must not be late is also the one
 * whose priority decays fastest.
 *
 * cthread_priority() sets the base priority and fails outright if asked for
 * more than the thread's maximum, so read the maximum first and clamp; only
 * the superuser can raise a maximum, and a sound device is not a reason to
 * require that.  SDL_OPENSTEP_THREAD_PRIORITY=off restores the old
 * do-nothing behaviour (the control arm), SDL_OPENSTEP_PRIORITY_BOOST sets
 * how far above the base to ask. */
#define OPENSTEP_PRIORITY_BOOST_DEFAULT 10

int SDL_SYS_SetThreadPriority(SDL_ThreadPriority priority)
{
    struct thread_sched_info si;
    unsigned int cnt = THREAD_SCHED_INFO_COUNT;
    const char *s;
    int boost;
    int want;
    kern_return_t kr;

    s = SDL_getenv("SDL_OPENSTEP_THREAD_PRIORITY");
    if (s != NULL && SDL_strcmp(s, "off") == 0) {
        return 0;
    }

    if (thread_info((thread_t)thread_self(), THREAD_SCHED_INFO,
                    (thread_info_t)&si, &cnt) != KERN_SUCCESS) {
        return SDL_SetError("thread_info(THREAD_SCHED_INFO) failed");
    }

    boost = OPENSTEP_PRIORITY_BOOST_DEFAULT;
    s = SDL_getenv("SDL_OPENSTEP_PRIORITY_BOOST");
    if (s != NULL && *s != '\0') {
        boost = SDL_atoi(s);
    }

    switch (priority) {
    case SDL_THREAD_PRIORITY_LOW:
        want = (int)si.base_priority - boost;
        break;
    case SDL_THREAD_PRIORITY_NORMAL:
        return 0;
    default:
        /* HIGH and TIME_CRITICAL both want "ahead of the drawing thread";
           there is no third rung to give them. */
        want = (int)si.base_priority + boost;
        break;
    }

    if (want > (int)si.max_priority) {
        want = (int)si.max_priority;
    }
    if (want < 0) {
        want = 0;
    }
    if (want == (int)si.base_priority) {
        return 0;
    }

    kr = cthread_priority(cthread_self(), want, (boolean_t)0);
    if (kr != KERN_SUCCESS) {
        return SDL_SetError("cthread_priority(%d) failed (max %d): %d",
                            want, (int)si.max_priority, (int)kr);
    }
    return 0;
}

void SDL_SYS_WaitThread(SDL_Thread *thread)
{
    if (thread->handle != NO_CTHREAD) {
        cthread_join(thread->handle);
        thread->handle = NO_CTHREAD;
    }
}

void SDL_SYS_DetachThread(SDL_Thread *thread)
{
    if (thread->handle != NO_CTHREAD) {
        cthread_detach(thread->handle);
        thread->handle = NO_CTHREAD;
    }
}
