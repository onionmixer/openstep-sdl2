/*
 * Which end of Mach's priority range is the good end?
 *
 * The probe next to this one established that a thread here starts at
 * base 10 with a ceiling of 18, and that thread_priority() accepts
 * anything from 0 to 18 and refuses more.  A ceiling of 18 hints that
 * larger is better, but Mach's own documentation uses both senses in
 * different places and the headers on this machine state neither.  The
 * answer decides which way SDL_SYS_SetThreadPriority has to map
 * SDL_THREAD_PRIORITY_TIME_CRITICAL, and getting it backwards would
 * make the audio thread the FIRST one starved rather than the last.
 *
 * So it is measured instead: two threads spin for a fixed wall-clock
 * span on a machine with one processor, at priorities given on the
 * command line, and each counts its own iterations.  Whichever
 * priority collects the iterations is the high one.  No interpretation
 * of the number is needed -- only of who ran.
 *
 *	cc -O -o /tmp/priodir openstep-thread-priority-direction.c
 *	/tmp/priodir 0 18 4	 main at 0, child at 18, for 4 seconds
 *	/tmp/priodir 18 0 4	 and the other way round
 *
 * Running it BOTH ways is the point.  A single run cannot tell a
 * priority effect from an artefact of which thread happened to be
 * scheduled first.
 */

#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_host.h>
#include <mach/cthreads.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>

static volatile int	go = 0;
static volatile long	main_count = 0;
static volatile long	child_count = 0;
static int		child_prio = 0;
static long		run_usec = 0;
static struct timeval	start_tv;

static long elapsed_usec(void)
{
    struct timeval	now;

    gettimeofday(&now, (struct timezone *)0);
    return (now.tv_sec - start_tv.tv_sec) * 1000000L
	 + (now.tv_usec - start_tv.tv_usec);
}

/*
 * The loop checks the clock only every 4096 turns.  gettimeofday costs
 * about 4.6 us here (measured by the other probe), so checking every
 * turn would make this a benchmark of the clock rather than of the
 * scheduler.
 */
static void spin(volatile long *counter)
{
    long	n = 0;

    for (;;) {
	n++;
	if ((n & 0xfff) == 0) {
	    *counter = n;
	    if (elapsed_usec() >= run_usec)
		break;
	}
    }
    *counter = n;
}

static any_t child(any_t arg)
{
    kern_return_t	r;

    (void)arg;
    r = thread_priority((thread_t)thread_self(), child_prio, FALSE);
    if (r != KERN_SUCCESS)
	printf("child: thread_priority(%d) failed (%d)\n", child_prio, (int)r);
    while (!go)
	;
    spin(&child_count);
    return (any_t)0;
}

int main(int argc, char **argv)
{
    cthread_t		t;
    kern_return_t	r;
    int			main_prio;
    int			secs;
    double		total;

    if (argc != 4) {
	printf("usage: %s <main-priority> <child-priority> <seconds>\n",
	       argv[0]);
	return 2;
    }
    main_prio  = atoi(argv[1]);
    child_prio = atoi(argv[2]);
    secs       = atoi(argv[3]);
    if (secs < 1) secs = 1;
    if (secs > 10) secs = 10;		/* it pins the only CPU */
    run_usec = (long)secs * 1000000L;

    r = thread_priority((thread_t)thread_self(), main_prio, FALSE);
    if (r != KERN_SUCCESS)
	printf("main: thread_priority(%d) failed (%d)\n", main_prio, (int)r);

    t = cthread_fork((cthread_fn_t)child, (any_t)0);

    gettimeofday(&start_tv, (struct timezone *)0);
    go = 1;
    spin(&main_count);
    cthread_join(t);

    total = (double)main_count + (double)child_count;
    printf("main  prio %2d : %10ld turns", main_prio, main_count);
    if (total > 0.0)
	printf("  (%5.1f %%)", 100.0 * (double)main_count / total);
    printf("\n");
    printf("child prio %2d : %10ld turns", child_prio, child_count);
    if (total > 0.0)
	printf("  (%5.1f %%)", 100.0 * (double)child_count / total);
    printf("\n");
    return 0;
}
