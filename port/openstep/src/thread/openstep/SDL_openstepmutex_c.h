/* Lock-wait accounting for the OPENSTEP backends.
 *
 * The audio callback thread has to be told apart from "the thread was busy"
 * and "the thread was not run at all"; the third possibility is "the thread
 * was waiting for an SDL mutex".  Only the mutex code can see that, so it
 * counts it, for one nominated thread, and the audio backend reads it out
 * when the device closes.  Nothing outside this port uses these. */
#ifndef SDL_openstepmutex_c_h_
#define SDL_openstepmutex_c_h_

#include "SDL_stdinc.h"
#include "SDL_thread.h"

/* Account SDL_LockMutex() waits taken by this thread, and reset the totals.
   Passing 0 stops accounting. */
extern void OPENSTEP_MutexWatchThread(SDL_threadID id);

/* Acquisitions counted, microseconds spent in them, and the worst one. */
extern void OPENSTEP_MutexWatchStats(Uint32 *acquires, Uint32 *total_us,
                                     Uint32 *max_us);

/* Nonzero when SDL mutexes block rather than yield -- reported so a log can
   say which arm produced it. */
extern int OPENSTEP_MutexIsBlocking(void);

#endif /* SDL_openstepmutex_c_h_ */
