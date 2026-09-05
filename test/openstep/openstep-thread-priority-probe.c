/*
 * What this machine will actually let a thread's priority be, and how
 * finely it can be timed.
 *
 * This exists because SDL asks for a high-priority audio thread
 * (SDL_audio.c:691 calls SDL_SetThreadPriority with
 * SDL_THREAD_PRIORITY_TIME_CRITICAL) and this port throws the request
 * away -- port/openstep/src/thread/openstep/SDL_systhread.c's
 * SDL_SYS_SetThreadPriority is `(void)priority; return
 * SDL_Unsupported();'.  So the audio thread runs at exactly the
 * priority of whatever else the program is doing, and on a single
 * processor that is the whole story of a stutter that follows screen
 * activity and disk reads.
 *
 * Before writing the implementation, three things have to be known and
 * none of them can be read out of a header:
 *
 *   1. Which direction is "higher"?  Mach numbers priorities 0..31 and
 *      the sense is not stated in any header on this machine.
 *   2. How far can an unprivileged -- or in our case a root -- thread
 *      move?  thread_priority() cannot raise a thread above its
 *      max_priority, and max_priority is itself only movable through a
 *      processor set port.
 *   3. Is gettimeofday actually fine-grained?  SDL's performance
 *      counter here is gettimeofday in microseconds
 *      (port/openstep/src/timer/SDL_systimer.c:96) and the API's unit
 *      says nothing about the clock's real step.
 *
 * Everything here is read-only with respect to the system.  The one
 * thing it writes is this process's own thread priorities, and the
 * process exits immediately afterwards.
 *
 * Build on the target:
 *	cc -O -o /tmp/prioprobe openstep-thread-priority-probe.c -lc
 */

#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_host.h>
#include <mach/thread_info.h>
#include <mach/cthreads.h>
#include <sys/time.h>
#include <stdio.h>

static void report(const char *who, thread_t th)
{
    struct thread_sched_info	si;
    unsigned int		cnt;
    kern_return_t		r;

    cnt = THREAD_SCHED_INFO_COUNT;
    r = thread_info(th, THREAD_SCHED_INFO, (thread_info_t)&si, &cnt);
    if (r != KERN_SUCCESS) {
	printf("  %-12s thread_info failed (%d)\n", who, (int)r);
	return;
    }
    printf("  %-12s policy=%d data=%d base=%d max=%d cur=%d"
	   " depressed=%d from=%d\n",
	   who, (int)si.policy, (int)si.data, (int)si.base_priority,
	   (int)si.max_priority, (int)si.cur_priority,
	   (int)si.depressed, (int)si.depress_priority);
}

/*
 * Ask for a priority and say what happened.  Both the answer and the
 * resulting base priority are printed: a call can return KERN_SUCCESS
 * and still land somewhere else, and the number that matters is where
 * the thread ended up, not what it asked for.
 */
static void try_priority(int want)
{
    struct thread_sched_info	si;
    unsigned int		cnt;
    kern_return_t		r;
    thread_t			th = thread_self();

    r = thread_priority(th, want, FALSE);
    cnt = THREAD_SCHED_INFO_COUNT;
    if (thread_info(th, THREAD_SCHED_INFO, (thread_info_t)&si, &cnt)
	    != KERN_SUCCESS) {
	printf("  ask %2d -> r=%d, and thread_info then failed\n",
	       want, (int)r);
	return;
    }
    printf("  ask %2d -> r=%-3d  base=%d cur=%d max=%d%s\n",
	   want, (int)r, (int)si.base_priority, (int)si.cur_priority,
	   (int)si.max_priority,
	   (r == KERN_SUCCESS) ? "" : "   (refused)");
}

/*
 * The clock's real step, and what one reading costs.
 *
 * The step is found by spinning until the value changes: a clock that
 * only ticks every 10 ms will sit still for thousands of calls and then
 * jump, and that jump is the number that decides whether a 125 ms
 * deadline can be measured at all.  The cost is the mean over enough
 * calls that the loop itself does not dominate.
 */
static void clock_probe(void)
{
    struct timeval	a, b;
    long		usec, min_step;
    int			i, spins;
    double		total;

    min_step = 0;
    for (i = 0; i < 8; i++) {
	gettimeofday(&a, (struct timezone *)0);
	spins = 0;
	do {
	    gettimeofday(&b, (struct timezone *)0);
	    spins++;
	} while (b.tv_sec == a.tv_sec && b.tv_usec == a.tv_usec
		 && spins < 10000000);
	usec = (b.tv_sec - a.tv_sec) * 1000000L + (b.tv_usec - a.tv_usec);
	if (i == 0 || usec < min_step)
	    min_step = usec;
    }
    printf("  smallest observed step: %ld us\n", min_step);

    gettimeofday(&a, (struct timezone *)0);
    for (i = 0; i < 100000; i++)
	gettimeofday(&b, (struct timezone *)0);
    gettimeofday(&b, (struct timezone *)0);
    usec = (b.tv_sec - a.tv_sec) * 1000000L + (b.tv_usec - a.tv_usec);
    total = (double)usec / 100000.0;
    printf("  100000 calls in %ld us = %.3f us each\n", usec, total);
}

static any_t child(any_t arg)
{
    (void)arg;
    printf("\nthe forked cthread, as SDL's audio thread would be:\n");
    report("cthread", (thread_t)thread_self());
    return (any_t)0;
}

int main(void)
{
    cthread_t	t;

    printf("=== priorities as they are ===\n");
    report("main", (thread_t)thread_self());

    t = cthread_fork((cthread_fn_t)child, (any_t)0);
    cthread_join(t);

    /*
     * Walk the whole Mach range rather than guess the sense.  Whichever
     * end is refused and whichever end moves `cur' is the answer, and
     * it is one run away instead of one assumption.
     */
    printf("\n=== what this thread is allowed to become ===\n");
    try_priority(0);
    try_priority(5);
    try_priority(10);
    try_priority(12);
    try_priority(18);
    try_priority(25);
    try_priority(31);

    printf("\n=== the clock SDL times audio with ===\n");
    clock_probe();

    return 0;
}
