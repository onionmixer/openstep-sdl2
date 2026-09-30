#ifndef SDL_openstepaudio_h_
#define SDL_openstepaudio_h_

#include "../SDL_sysaudio.h"

/* SDL_sysaudio.h undefines this after declaring SDL_AudioDevice. Backend
   callbacks use the same conventional shorthand as upstream drivers. */
#define _THIS SDL_AudioDevice *_this

#define OPENSTEP_AUDIO_QUEUE_SLOTS 8
/*
 * Six buffers of an eighth of a second, so the queue is the same 375 ms it
 * has been since openstep.3 -- but the RESERVE is not the same, and the
 * reserve is what breaks up.
 *
 * The comment that used to sit here said the worst-phase reserve was
 * (AHEAD - 1) buffers, 250 ms at the old geometry.  That was measured on
 * the machine and it is wrong: the kernel's mixer runs some descriptors
 * AHEAD of the play point and pads a short one with silence rather than
 * stopping, so
 *
 *      reserve = (AHEAD - 1) x buffer  -  C,      C = 160-165 ms
 *
 * which left 85-90 ms, against a glquake frame of 165-176.  A frame's
 * worth of lateness could not fit, which is the stutter.
 *
 * Smaller buffers are strictly better here, because reserve is
 * (latency - buffer - C): six sixteenths beat three eighths at the same
 * latency.  With the primer below the measured reserve is 220-280 ms.
 * Six and not seven because libsound starts at most six sounds at once;
 * a seventh would wait for its reply thread to start it.
 *
 * docs/measurements/README.md has the measurements and the program
 * that made them.
 */
#define OPENSTEP_AUDIO_QUEUE_AHEAD 6

/*
 * The first region the kernel sees decides how far ahead its mixer runs,
 * and it holds that for the life of the DMA.  One descriptor -- 8192
 * bytes, which the kernel takes from page_size and userland cannot change
 * -- makes that lead as short as it goes.  Measured: 8192 buys 60 ms of
 * reserve over the 16384 that the first ordinary buffer would have given,
 * and 130 ms over letting the ordinary buffer be first.
 */
#define OPENSTEP_AUDIO_PRIMER_BYTES 8192

/* A submission this slow is worth a line of its own.  25 ms is well past
 * anything the work itself costs -- the whole submit is normally under a
 * millisecond -- so every one of these is a stall, not a cost. */
#define OPENSTEP_AUDIO_LONGSUB_US   25000
/* 64, not 16.  The run that sounded worst had 282 slow submissions and
 * the table showed the first 16, all of them before 28 s -- the 267 in
 * the 25-100 ms band, which are what makes the music grate rather than
 * gap, were entirely invisible.  Whether they come in runs or scattered
 * is the difference between "the loop cannot keep real time" and "there
 * were some bad moments", and only a chronology says which. */
#define OPENSTEP_AUDIO_LONGSUB_SLOTS 64

/* A gap this long is worth remembering individually, not just counting.
 *
 * This was 100 ms, chosen when gaps ran to 189.  With the timer fix and
 * the game's synthesiser halved the worst gap is 55, so 100 ms records
 * nothing at all -- and the listener reports a stutter "around where the
 * first song starts", which is exactly the kind of event a threshold
 * above the observed maximum cannot see.  25 ms is well clear of a
 * healthy refill and still far below the queue. */
#define OPENSTEP_AUDIO_LONG_US     25000
#define OPENSTEP_AUDIO_LONG_SLOTS  64

struct SDL_PrivateAudioData
{
    Uint8 *mixbuf;
    Uint32 mixlen;
    Uint32 delay_ms;
    int started;
    int primed;
    int underruns;
    int playfailures;
    /*
     * WHY THE BACKEND TIMES ITSELF.
     *
     * The reserve -- how late one submission may be before the kernel pads
     * with silence -- was measured on the machine and raised from 85-90 ms
     * to 220-280.  The games still break up, and the kernel driver's own
     * counters say the queue empties COMPLETELY about once a second.  So
     * the question is no longer how much slack there is; it is how long
     * this thread actually fails to come back, and that has never been
     * measured.
     *
     * `gap` is the interval from WaitDevice returning to the next
     * PlayDevice entering: the callback, the format conversion, the wait
     * for SDL's mixer_lock, and any time this thread spent not scheduled.
     * It is per OUTPUT BUFFER, not per callback -- with a conversion
     * stream (both consumers have one) a single callback can feed several
     * buffers, and each of those still has its own wait and its own gap.
     *
     * `wait` is how long SNDWait blocked, which is how far ahead we were.
     * `play` is what this backend itself costs.
     *
     * Long gaps are kept with the time they happened, not just counted:
     * an event that happens once a second needs a chronology, not an
     * average.  Nothing is printed while audio is running.
     */
    Uint32 t_wait_ret;                  /* us at last WaitDevice return */
    Uint32 t_open;                      /* us at first PlayDevice */
    Uint32 gap_max, wait_max, play_max; /* us */
    /*
     * WHEN the worst submission happened, and how many buffers had gone
     * before it.  The gap histogram covers WaitDevice-return to
     * PlayDevice-entry; `play` is the submission itself, which is a
     * different interval, so "no gap over 100 ms" says nothing about a
     * 399 ms submit -- and one was seen (arm 3, water1).  A submission
     * that slow at buffer 2 is the device starting; the same number at
     * buffer 900 is a stall the reserve cannot absorb.  Two words tell
     * those apart, and nothing is printed while audio is running.
     */
    Uint32 play_max_when;               /* ms since the first buffer */
    Uint32 play_max_nbuf;               /* buffers submitted before it */
    /*
     * WHERE THOSE MILLISECONDS WENT.
     *
     * Measured: buffer 202, 12.9 s into water1, one submission of 405 ms.
     * That is mid-playback and past the 240-280 ms reserve, so it is a
     * real stall and not the device starting.  A submission is four
     * things, and only one of them is ours to fix:
     *
     *   drain   SNDWait on the oldest sound, when the slots are full.
     *           Bounded by `wait_max`, which was 99 ms in that run, so it
     *           cannot be the whole 405 -- but it is measured here too,
     *           because "cannot be the whole" is not "is not part".
     *   alloc   SDL_malloc of 11 KB.  cthreads' malloc takes a mutex, and
     *           this port has already shown what a cthreads mutex does to
     *           a waiter: mutex_spin_limit is 0, so it yields forever.
     *           The consumer allocates on its own thread (water1 reloads
     *           music with free/malloc/fread), so the two can collide.
     *   copy    SDL_memcpy of the same 11 KB.  About a millisecond.
     *           Kept only so it can be ruled out with a number.
     *   start   SNDStartPlaying, which takes libsound's own queue lock --
     *           held by its reply thread across performance_started and
     *           performance_ended.  Not ours; if this is the answer the
     *           fix is to stop calling it per buffer.
     *
     * Beside them, the processor time this thread consumed inside the
     * same submission: work spends it, a blocked or unscheduled thread
     * does not.  And two ways of keeping the four, because the worst
     * submission may not happen twice: the breakdown OF the worst one,
     * and the worst each part ever reached on its own.
     */
    /*
     * HOW OFTEN, not just how bad.
     *
     * The maximum alone cannot answer the question the listener asked --
     * "it stutters occasionally".  Three runs each reported exactly one
     * ~400 ms submission, but a maximum is one sample: it cannot say
     * whether that was the only slow one or the worst of forty.  So every
     * submission is counted into a histogram, and every submission over
     * 25 ms is written down with the things that would identify a cause:
     *
     *   when/nbuf   a chronology, to line up against what the game was
     *               doing (the listener hears it during disk load)
     *   start       how much of it was SNDStartPlaying, which is where
     *               all of the last two maxima were
     *   count       how many sounds this backend was holding when it
     *               called SNDStartPlaying.  libsound's
     *               initiate_performance refuses to start a seventh
     *               concurrent sound (3*pending > 15), and QUEUE_AHEAD is
     *               6 -- so we sit exactly on that boundary and this is
     *               the number that says whether we crossed it.
     *
     * SNDWait gets a histogram too: if the waits stall in the same runs,
     * the stall is libsound's whole pipeline rather than the start call.
     */
    Uint32 submit_hist[8];
    Uint32 wait_hist[8];
    Uint32 nlongsub;
    Uint32 longsub_when[OPENSTEP_AUDIO_LONGSUB_SLOTS];   /* ms since first buffer */
    Uint32 longsub_us[OPENSTEP_AUDIO_LONGSUB_SLOTS];     /* whole submission */
    Uint32 longsub_start[OPENSTEP_AUDIO_LONGSUB_SLOTS];  /* SNDStartPlaying part */
    Uint32 longsub_nbuf[OPENSTEP_AUDIO_LONGSUB_SLOTS];
    Uint32 longsub_count[OPENSTEP_AUDIO_LONGSUB_SLOTS];  /* queue depth at the call */
    /*
     * AND WHETHER THE TASK WAS PAGING WHILE IT STALLED.
     *
     * The stalls happen at the same points in the game every time -- the
     * first song, a screen transition, the ending -- and they only appear
     * when the disk is really busy.  Two very different things could put
     * disk work there, and they need opposite repairs:
     *
     *   the game reading its own files   its data is 849 KB in total, so
     *                                    reading all of it once at start
     *                                    would end it
     *   the executable being paged in    2.9 MB with SDL and Mesa linked
     *                                    in; entering a new scene touches
     *                                    code that has never been read
     *
     * TASK_EVENTS_INFO counts pageins for this task, so the difference
     * across one submission says which.  A stall with no pageins is the
     * first; a stall that pages is the second.
     */
    Uint32 longsub_pagein[OPENSTEP_AUDIO_LONGSUB_SLOTS];
    Uint32 longsub_fault[OPENSTEP_AUDIO_LONGSUB_SLOTS];
    Uint32 pagein_at_open, fault_at_open;
    int count_at_start;                 /* set by Enqueue, read by PlayDevice */
    /*
     * WHERE THE MUSIC STARTS, on the same clock as everything else.
     *
     * The device is opened paused and stays paused until the game plays
     * its first song, and while it is paused the core feeds this backend
     * silence without ever calling the application callback.  So the
     * moment the pause lifts is the moment the synthesiser, the
     * conversion stream and the resampler all begin working for the first
     * time -- and it is where the listener hears a stutter.  Nothing in
     * the report has been able to point at it, because the backend never
     * looked at the one flag that marks it.
     */
    /*
     * TWO SWITCHES FOR THE SAME MEASUREMENT, both default to what ships.
     *
     * 197 of 1351 submissions took over 25 ms and every one of them was
     * inside SNDStartPlaying with the queue holding exactly 5 -- we start
     * the sixth concurrent sound every single time, and libsound's
     * initiate_performance refuses a seventh (3*pending > 15).  If its
     * count still includes a finished sound its reply thread has not
     * reaped, our start is deferred until that thread runs, and that
     * thread was seen at base priority 0.
     *
     *   ahead   SDL_OPENSTEP_QUEUE_AHEAD: how many sounds to keep in
     *           flight.  Five steps off the boundary at the cost of one
     *           buffer of reserve.
     *   raise   SDL_OPENSTEP_HELPER_PRIORITY: once, after the first
     *           submission, lift every thread in this task that sits at
     *           base priority 0 -- which right then is libsound's reply
     *           thread and nothing else; the game's main thread is at 10.
     *
     * They are independent on purpose: if backing off the boundary alone
     * ends the stalls, the cause is the admission check; if only the
     * priority does, the cause is that thread not being scheduled.
     */
    int ahead;
    int raise_helpers;
    int helpers_raised;
    int hooked;
    int unpaused;                       /* have we seen an unpaused buffer */
    Uint32 unpause_when;                /* ms since the first buffer */
    Uint32 unpause_nbuf;
    Uint32 play_max_cpu;                /* thread cpu us inside that submit */
    Uint32 play_parts[4];               /* this submit: drain, alloc, copy, start */
    Uint32 play_max_parts[4];           /* the same four, for the worst submit */
    Uint32 part_max[4];                 /* the worst each part ever was, alone */
    Uint32 nbuf;
    Uint32 gap_hist[8];
    Uint32 nlong;                       /* gaps over OPENSTEP_AUDIO_LONG_US */
    Uint32 long_when[OPENSTEP_AUDIO_LONG_SLOTS];  /* ms since first buffer */
    Uint32 long_gap[OPENSTEP_AUDIO_LONG_SLOTS];   /* us */
    /*
     * And what this thread was DOING during that gap.
     *
     * Wall time alone cannot say why a refill was late.  The kernel keeps
     * per-thread user and system time (THREAD_BASIC_INFO), so the processor
     * time this thread actually consumed across the same interval separates
     * the two answers that call for opposite fixes:
     *
     *   cpu ~= gap   the thread was running the whole time -- the callback,
     *                the resampler, or a spin on a mutex.  Priority cannot
     *                help; the work has to get cheaper.
     *   cpu << gap   the thread was runnable-but-not-run, or blocked.  That
     *                is what raising its priority is for.
     *
     * base/cur priority come from the same call, so a later build that
     * raises the priority can be shown to have actually raised it.
     */
    Uint32 cpu_wait_ret;                          /* thread cpu us at WaitDevice exit */
    Uint32 long_cpu[OPENSTEP_AUDIO_LONG_SLOTS];   /* cpu us spent within that gap */
    int base_pri, cur_pri;
    /* THREAD_SCHED_INFO also answers "was this thread's priority depressed
       by swtch_pri()?", which is what tells scheduler ageing apart from a
       cthreads yield loop.  Self-sampling can only see a depression that
       outlived the wake-up, so a zero here is not proof of absence. */
    int max_pri, depressed;
    /*
     * THE BUFFERS LIBSOUND IS GIVEN, ALLOCATED ONCE.
     *
     * This backend used to hand SoundKit a fresh SDL_malloc for every
     * buffer and free it when SNDWait returned -- sixteen allocations a
     * second, each of eleven kilobytes.  It was ruled out as an
     * optimisation on CPU grounds, correctly: malloc's worst was 854 us
     * against 508,008 us inside SNDStartPlaying.  That was the wrong
     * question.
     *
     * The stalls only appear when the disk is REALLY busy -- reading a
     * raw device, which the buffer cache cannot serve -- and they are
     * inside the driver call, with no processor time.  A buffer the
     * process has already faulted in and handed over before does not need
     * the paging path again; a fresh one does, and the paging path is the
     * one the disk is holding.
     *
     * Measured, bench, 17 rounds of 20 s each under a raw-device read,
     * with the arm order rotated so position in the round cannot explain
     * it: fresh malloc stalled in 8 of 17 rounds; the pool stalled in
     * none of 17, across 5,524 submissions.
     *
     * Every page is written once at open, so the faults happen there and
     * never again.  SDL_OPENSTEP_BUFFER_POOL=0 turns it off, which is
     * what the arms above were.
     */
    void *pool[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int pooled;
    void *sounds[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int tags[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int next_tag;
    int head;
    int count;
    /*
     * THE STREAM PATH (the default; SDL_OPENSTEP_AUDIO_API=sound turns it off).
     *
     * One NXPlayStream on one NXSoundOut, fed from a ring of buffers that
     * are never touched again until SoundKit says it has finished with
     * them.  The objects are Objective-C and held as void * so this
     * header stays C; only the backend's one SoundKit thread sends them
     * messages (SDL_openstepaudio.m, "ONE THREAD SPEAKS OBJECTIVE-C").
     * st_tag_of[slot] is the tag in flight in that slot, 0 when free; the
     * completion callback frees a slot only when the tag it reports is the
     * one the slot holds.  Everything from st_ring down is shared with
     * SoundKit's reply thread and taken under the backend's one
     * process-wide stream lock.
     */
    int use_stream;
    void *st_dev;                       /* NXSoundOut */
    void *st_stream;                    /* NXPlayStream */
    void *st_delegate;                  /* the callback target; never freed */
    Uint8 *st_ring[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int st_ring_ok;
    int st_tag_of[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int st_next_tag;
    int st_outstanding;
    int st_out_max;
    int st_failed;
    unsigned int st_submitted, st_started, st_completed;
    unsigned int st_stale_cb, st_underrun_cb, st_timeouts, st_empty;
    int st_async_fail;                  /* the SoundKit thread saw playBuffer refuse; the audio thread reports it */
    /* SDL_OPENSTEP_AUDIO_TRACE only (docs/PLAN_RELEASE_OPENSTEP5.md 16):
       per-buffer and per-completion time traces, written out at close.
       NULL when not tracing.  ctrace is written by SoundKit's reply thread
       under the stream lock. */
    void *trace;                        /* OPENSTEP_TraceRow[OPENSTEP_TRACE_ROWS] */
    unsigned int trace_n;               /* rows begun; the ring index is trace_n % rows */
    int trace_cur;                      /* the row of this PlayDevice/WaitDevice pair, -1 none */
    void *ctrace;                       /* OPENSTEP_CompRow[OPENSTEP_TRACE_ROWS] */
    unsigned int ctrace_n;
};

#endif
