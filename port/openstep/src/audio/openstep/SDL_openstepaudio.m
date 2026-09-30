/* OPENSTEP SoundKit output backend for SDL2. The common SDL2 audio core owns
   the callback thread and converts input to this driver's S16MSB device
   format; this backend retains only queued SoundKit buffers. */
#include "../../SDL_internal.h"

#ifdef SDL_AUDIO_DRIVER_OPENSTEP

#import <SoundKit/SoundKit.h>
#import <sound/sound.h>
#import <Foundation/Foundation.h>   /* NSThread, NSAutoreleasePool for the stream path */
#import <mach/cthreads.h>   /* mutex_t, condition_t for the stream path */

#include <stdio.h>    /* the trace file (SDL_OPENSTEP_AUDIO_TRACE) */
/* getpid, for its name: <unistd.h> declares it only under _POSIX_SOURCE;
   this is <bsd/libc.h>'s declaration */
extern int getpid(void);
#include "SDL_audio.h"
#include "SDL_timer.h"
#include "../SDL_sysaudio.h"
#include "SDL_openstepaudio.h"
#include "../../thread/openstep/SDL_openstepmutex_c.h"
#include "../../thread/SDL_systhread.h"   /* SDL_SYS_SetThreadPriority, for the SoundKit thread */

/* thread_info() is declared in mach_interface.h, thread_self() in
 * mach_init.h, and THREAD_BASIC_INFO in thread_info.h -- the same set the
 * priority probe under test/openstep uses, which is the code that
 * established these numbers on this machine in the first place. */
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_interface.h>
#include <mach/thread_info.h>
#include <mach/task_info.h>

/* Microseconds.  This port's SDL_GetPerformanceCounter is gettimeofday with
 * a 1 MHz frequency (port/openstep/src/timer/SDL_systimer.c), measured at
 * 4.6 us a call with a 5 us step -- four calls a buffer is 0.03% of one
 * processor at this geometry.  Truncated to 32 bits deliberately: every
 * interval here is milliseconds, and cc 2.7.2.1 miscompiles some long long
 * comparisons. */
static Uint32 OPENSTEPAUDIO_Now(void)
{
    return (Uint32)SDL_GetPerformanceCounter();
}

/* This thread's own processor time, in microseconds, and what the scheduler
 * currently thinks of it.  One Mach call; taken twice a buffer, which at
 * sixteen buffers a second is not a cost worth avoiding, and it is the only
 * way to tell "the thread was busy" from "the thread was not run". */
static Uint32 OPENSTEPAUDIO_CpuUs(_THIS)
{
    struct thread_basic_info bi;
    struct thread_sched_info si;
    unsigned int cnt = THREAD_BASIC_INFO_COUNT;

    if (thread_info((thread_t)thread_self(), THREAD_BASIC_INFO,
                    (thread_info_t)&bi, &cnt) != KERN_SUCCESS) {
        return 0;
    }
    cnt = THREAD_SCHED_INFO_COUNT;
    if (thread_info((thread_t)thread_self(), THREAD_SCHED_INFO,
                    (thread_info_t)&si, &cnt) == KERN_SUCCESS) {
        _this->hidden->max_pri = (int)si.max_priority;
        if (si.depressed) {
            _this->hidden->depressed = 1;
        }
    }
    _this->hidden->base_pri = (int)bi.base_priority;
    _this->hidden->cur_pri  = (int)bi.cur_priority;
    return (Uint32)bi.user_time.seconds * 1000000U
         + (Uint32)bi.user_time.microseconds
         + (Uint32)bi.system_time.seconds * 1000000U
         + (Uint32)bi.system_time.microseconds;
}

/* This task's page-in and fault counters.  One Mach call; taken twice a
 * buffer, beside the two thread_info calls already there. */
/*
 * TASK_EVENTS_INFO IS NOT IMPLEMENTED ON THIS KERNEL.
 *
 * It was added to answer "was the task paging while it stalled", reported
 * zero everywhere, and the zero was believed for one whole round of
 * measurement.  It is not a zero: task_info returns KERN_INVALID_ARGUMENT
 * (4) for this flavour -- proved with a program that touches 64 MB of
 * fresh pages and still gets the same failure.  TASK_BASIC_INFO's cpu
 * times are dead here in the same way.
 *
 * So it returns the error rather than a number, the callers report "not
 * available" once, and nothing prints a zero that could be mistaken for a
 * measurement again.
 */
static int OPENSTEPAUDIO_Events(Uint32 *pageins, Uint32 *faults)
{
    struct task_events_info ei;
    unsigned int cnt = TASK_EVENTS_INFO_COUNT;

    *pageins = 0;
    *faults = 0;
    if (task_info(task_self(), TASK_EVENTS_INFO,
                  (task_info_t)&ei, &cnt) != KERN_SUCCESS) {
        return 0;
    }
    *pageins = (Uint32)ei.pageins;
    *faults = (Uint32)ei.faults;
    return 1;
}

/* Buckets in microseconds: 25, 50, 100, 150, 250, 375, 500 ms and above.
 * 375 ms is the queue and 250 is the measured reserve, so a gap landing in
 * the last two buckets is one the queue cannot absorb. */
static void OPENSTEPAUDIO_Record(_THIS, Uint32 gap, Uint32 cpu)
{
    int b;

    if      (gap <  25000) b = 0;
    else if (gap <  50000) b = 1;
    else if (gap < 100000) b = 2;
    else if (gap < 150000) b = 3;
    else if (gap < 250000) b = 4;
    else if (gap < 375000) b = 5;
    else if (gap < 500000) b = 6;
    else                   b = 7;
    ++_this->hidden->gap_hist[b];
    if (gap > _this->hidden->gap_max) _this->hidden->gap_max = gap;
    if (gap >= (Uint32)OPENSTEP_AUDIO_LONG_US) {
        Uint32 n = _this->hidden->nlong;
        if (n < (Uint32)OPENSTEP_AUDIO_LONG_SLOTS) {
            _this->hidden->long_gap[n] = gap;
            _this->hidden->long_cpu[n] = cpu;
            _this->hidden->long_when[n] =
                (OPENSTEPAUDIO_Now() - _this->hidden->t_open) / 1000U;
        }
        ++_this->hidden->nlong;
    }
}

/* Submission buckets, in microseconds: 0.5, 1, 2, 5, 25, 100, 250 ms and
 * above.  The low edges are that fine because a healthy submission is a
 * memcpy and a message -- if the bulk stops landing in the first two
 * buckets, the cost has moved, and that is a different fault from a stall. */
static void OPENSTEPAUDIO_RecordSubmit(_THIS, Uint32 us)
{
    int b;

    if      (us <    500) b = 0;
    else if (us <   1000) b = 1;
    else if (us <   2000) b = 2;
    else if (us <   5000) b = 3;
    else if (us <  25000) b = 4;
    else if (us < 100000) b = 5;
    else if (us < 250000) b = 6;
    else                  b = 7;
    ++_this->hidden->submit_hist[b];
}

/* SNDWait buckets, in microseconds: 25, 50, 62, 75, 100, 150, 250 ms and
 * above.  62 ms is one buffer, which is what a healthy wait is. */
static void OPENSTEPAUDIO_RecordWait(_THIS, Uint32 us)
{
    int b;

    if      (us <  25000) b = 0;
    else if (us <  50000) b = 1;
    else if (us <  62000) b = 2;
    else if (us <  75000) b = 3;
    else if (us < 100000) b = 4;
    else if (us < 150000) b = 5;
    else if (us < 250000) b = 6;
    else                  b = 7;
    ++_this->hidden->wait_hist[b];
}

/* Lift libsound's background thread out of the bottom priority band.
 *
 * Called once, after the first sound has been started, because that is
 * when libsound forks its reply thread -- before that there is nothing to
 * find.  Only threads at base priority 0 are touched: that is where the
 * reply thread was observed (sndcost saw "base 0 cur 0 depressed 1"), and
 * the game's own threads are at 10 or above, so nothing else moves. */
static void OPENSTEPAUDIO_RaiseHelpers(_THIS)
{
    thread_array_t list;
    unsigned int n, i;
    thread_t me = thread_self();
    int pri = _this->hidden->max_pri > 0 ? _this->hidden->max_pri : 18;

    if (task_threads(task_self(), &list, &n) != KERN_SUCCESS) {
        return;
    }
    for (i = 0; i < n; i++) {
        struct thread_basic_info bi;
        unsigned int c1 = THREAD_BASIC_INFO_COUNT;
        if (list[i] == me) continue;
        if (thread_info(list[i], THREAD_BASIC_INFO,
                        (thread_info_t)&bi, &c1) != KERN_SUCCESS) continue;
        if (bi.base_priority != 0) continue;
        if (thread_priority(list[i], pri, FALSE) == KERN_SUCCESS) {
            ++_this->hidden->helpers_raised;
        }
    }
}

static void OPENSTEPAUDIO_DrainOne(_THIS)
{
    const int slot = _this->hidden->head;
    if (_this->hidden->count > 0) {
        Uint32 t0 = OPENSTEPAUDIO_Now();
        Uint32 held;
        if (SNDWait(_this->hidden->tags[slot]) != SND_ERR_NONE) {
            SDL_SetError("OPENSTEP SoundKit wait failed");
        }
        held = OPENSTEPAUDIO_Now() - t0;
        if (held > _this->hidden->wait_max) _this->hidden->wait_max = held;
        OPENSTEPAUDIO_RecordWait(_this, held);
        if (!_this->hidden->pooled) {
            SDL_free(_this->hidden->sounds[slot]);
        }
        _this->hidden->sounds[slot] = NULL;
        _this->hidden->head = (slot + 1) % OPENSTEP_AUDIO_QUEUE_SLOTS;
        --_this->hidden->count;
    }
}

/*
 * ---------------------------------------------------------------------------
 * THE STREAM PATH.
 *
 * Why it exists: measured on the machine (2026-09-29, a 440 Hz tone, no
 * load, ten blind trials), the per-sound queue this backend has always used
 * -- one SNDStartPlaying per buffer -- broke the tone up rapidly on every
 * trial, while the same buffers written to one NXPlayStream played clean
 * after a blip at the very start.  In the game the same bytes that played
 * clean on one run gurgled on another (identical at the SNDStartPlaying
 * argument, sample for sample), so the defect is below this code and the
 * only thing this code controls is how the audio is handed over.
 *
 * It is the default.  SDL_OPENSTEP_AUDIO_API=sound selects the per-sound
 * path, which stays as it was.  An earlier port rejected NXPlayStream for noise and underruns; its
 * notes put that down to reusing one buffer, which is why this one keeps a
 * ring and waits for each buffer's completion before writing it again.
 * The data is big-endian, as for SNDStartPlaying (heard on the machine).
 * ---------------------------------------------------------------------------
 */
/*
 * ONE THREAD SPEAKS OBJECTIVE-C.
 *
 * Foundation's NSThread specification: "do not use cthread_fork() to create
 * a thread that executes an Objective-C message".  SDL's threads are
 * cthread_fork threads (thread/openstep/SDL_systhread.c), and an autorelease
 * pool made on one of them shares Foundation's single-threaded pool stack
 * with the main thread's.  Measured on the machine (2026-09-29): with every
 * SoundKit call made on SDL's audio thread, glquake_radeon died in 3 runs of
 * 30, right after its audio device started, with "message addObject: sent
 * to freed object" (docs/PLAN_RELEASE_OPENSTEP5.md 13).  So every SoundKit
 * message on the stream path is sent by one NSThread, detached once and
 * kept for the life of the process; the other threads post a request to it
 * in plain C.  Opening and closing wait for the answer; a submission does
 * not: waiting cost the audio thread 3.5 ms a buffer (18.8 at the 90th
 * percentile), long enough to miss the gap between two frames of a game
 * that holds the audio lock for the frame, and the device ran dry twice as
 * often (docs/PLAN_RELEASE_OPENSTEP5.md 15, 17).  The SoundKit thread takes
 * the requests in order and records a submission's outcome itself.  The one
 * message sent anywhere else is the detach itself, from the thread that
 * first opens a stream -- normally the main thread.
 *
 * RULE: nobody waits for that thread while holding openstep_stream_lock.
 * SoundKit's reply thread takes the lock in the delegate below, and a
 * SoundKit call the thread is making may need the reply thread to move.
 */
static mutex_t openstep_stream_lock = NULL;     /* every device's stream state; never freed */
static mutex_t openstep_sk_lock = NULL;         /* the request queue */
static condition_t openstep_sk_req = NULL;
static condition_t openstep_sk_done = NULL;
static int openstep_sk_started = 0;

enum { OPENSTEP_SK_OPEN = 1, OPENSTEP_SK_SUBMIT, OPENSTEP_SK_CLOSE };

/* What a waited-for request (OPEN, CLOSE) answers, into the requester's own
   variable: SDL's error state is per thread, so the REQUESTER sets it. */
struct OPENSTEP_SkAnswer {
    int result;                 /* 0, or 1 on failure */
    int code;                   /* the NXSoundDeviceError, when there is one */
    const char *why;            /* a static string when result != 0 */
};

/*
 * DIAGNOSTICS: SDL_OPENSTEP_AUDIO_TRACE=<path> writes <path>.<pid>.<n> at
 * each close -- one row per PlayDevice/WaitDevice pair and one per
 * completion, absolute microseconds on OPENSTEPAUDIO_Now's clock.  Plain C
 * all the way; nothing is allocated when the variable is not set.
 * docs/PLAN_RELEASE_OPENSTEP5.md 16.
 */
#define OPENSTEP_TRACE_ROWS 2048
typedef struct {
    Uint32 entry;               /* PlayDevice entered */
    Uint32 wait_ret_prev;       /* the previous WaitDevice returned */
    int out_entry;              /* st_outstanding at entry (0 = ran dry) */
    unsigned int comp_entry;    /* st_completed at entry */
    Uint32 slot_b, slot_e;      /* StreamSubmit: entered, reservation done */
    Uint32 sk_enter, sk_post, sk_pick, sk_end, sk_done;   /* the SUBMIT request */
    Uint32 wait_b, wait_e;      /* StreamWait */
} OPENSTEP_TraceRow;
typedef struct {
    Uint32 when;
    int tag;
} OPENSTEP_CompRow;

/* The request queue.  Numbered in the order posted; the thread finishes
   them in that order and publishes the number of the last one finished, so
   a waiter knows every earlier request -- a device's submissions before its
   CLOSE, bookkeeping included -- is done. */
typedef struct {
    int op;
    unsigned long seq;
    SDL_AudioDevice *dev;
    int slot, tag, arg;
    OPENSTEP_TraceRow *tr;              /* SUBMIT: the trace row to stamp, or NULL */
    struct OPENSTEP_SkAnswer *ans;      /* OPEN, CLOSE: where the answer goes */
} OPENSTEP_SkReq;
#define OPENSTEP_SK_FIFO 32
static struct {
    OPENSTEP_SkReq q[OPENSTEP_SK_FIFO];
    int head, count;
    unsigned long posted, done;         /* sequence numbers */
} openstep_sk;

/* priorities, measured once: the SoundKit thread before and after it asks
   for the audio thread's rung (and what the request returned), and the
   reply thread on its first completion */
static int openstep_skpri[6] = { -1, -1, -1, -1, -1, -1 };   /* base cur max  rc  base cur */
static int openstep_rppri[3] = { -1, -1, -1 };               /* base cur max */
static int openstep_trace_seq = 0;

static void OPENSTEPAUDIO_ThreadPri(int *base, int *cur, int *max)
{
    struct thread_basic_info bi;
    struct thread_sched_info si;
    unsigned int cnt = THREAD_BASIC_INFO_COUNT;

    if (thread_info((thread_t)thread_self(), THREAD_BASIC_INFO,
                    (thread_info_t)&bi, &cnt) == KERN_SUCCESS) {
        *base = (int)bi.base_priority;
        *cur = (int)bi.cur_priority;
    }
    cnt = THREAD_SCHED_INFO_COUNT;
    if (max != NULL && thread_info((thread_t)thread_self(), THREAD_SCHED_INFO,
                                   (thread_info_t)&si, &cnt) == KERN_SUCCESS) {
        *max = (int)si.max_priority;
    }
}

/* the row of the PlayDevice/WaitDevice pair in progress, or NULL */
static OPENSTEP_TraceRow *OPENSTEPAUDIO_TraceRow(SDL_AudioDevice *_this)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    if (h == NULL || h->trace == NULL || h->trace_cur < 0) {
        return NULL;
    }
    return &((OPENSTEP_TraceRow *)h->trace)[h->trace_cur];
}

@interface OPENSTEPAudioStreamDelegate : NSObject
{
@public
    struct SDL_PrivateAudioData *owner;     /* read and written only under openstep_stream_lock */
}
@end

@implementation OPENSTEPAudioStreamDelegate
- (void)soundStream:(id)sender didStartBuffer:(int)tag
{
    struct SDL_PrivateAudioData *h;
    (void)sender; (void)tag;
    mutex_lock(openstep_stream_lock);
    h = owner;
    if (h != NULL) {
        ++h->st_started;
    }
    mutex_unlock(openstep_stream_lock);
}
- (void)soundStream:(id)sender didCompleteBuffer:(int)tag
{
    struct SDL_PrivateAudioData *h;
    int slot;
    (void)sender;
    slot = (tag > 0) ? tag % OPENSTEP_AUDIO_QUEUE_SLOTS : 0;
    mutex_lock(openstep_stream_lock);
    h = owner;
    if (openstep_rppri[0] < 0) {
        OPENSTEPAUDIO_ThreadPri(&openstep_rppri[0], &openstep_rppri[1], &openstep_rppri[2]);
    }
    if (h != NULL && h->ctrace != NULL) {
        OPENSTEP_CompRow *c = &((OPENSTEP_CompRow *)h->ctrace)[h->ctrace_n % OPENSTEP_TRACE_ROWS];
        c->when = OPENSTEPAUDIO_Now();
        c->tag = tag;
        ++h->ctrace_n;
    }
    if (h != NULL) {
        if (tag > 0 && h->st_tag_of[slot] == tag) {
            h->st_tag_of[slot] = 0;
            --h->st_outstanding;
            ++h->st_completed;
        } else {
            ++h->st_stale_cb;
        }
    }
    mutex_unlock(openstep_stream_lock);
}
- (void)soundStreamDidUnderrun:(id)sender
{
    struct SDL_PrivateAudioData *h;
    (void)sender;
    mutex_lock(openstep_stream_lock);
    h = owner;
    if (h != NULL) {
        ++h->st_underrun_cb;
    }
    mutex_unlock(openstep_stream_lock);
}
@end

/* The three requests, as the SoundKit thread performs them.  Nothing else
   calls these. */
static int OPENSTEPAUDIO_SkOpen(SDL_AudioDevice *_this, const char **why, int *code)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    NXSoundOut *dev;
    NXPlayStream *st;
    NXSoundParameters *params;
    OPENSTEPAudioStreamDelegate *del;
    NXSoundDeviceError e;

    /* A class setting, and only honoured before the first NXSoundDevice
       exists: SoundKit's replies come on its own thread, which is the only
       way they can arrive here -- nothing runs a run loop for this backend. */
    [NXSoundDevice setUseSeparateThread:YES];
    dev = [[NXSoundOut alloc] init];
    h->st_dev = (void *)dev;
    if (dev == nil) {
        *why = "NXSoundOut did not initialise";
        return 1;
    }
    params = [[NXSoundParameters alloc] init];
    [params setParameter:NX_SoundStreamDataEncoding toInt:NX_SoundStreamDataEncoding_Linear16];
    [params setParameter:NX_SoundStreamSamplingRate toFloat:(float)_this->spec.freq];
    [params setParameter:NX_SoundStreamChannelCount toInt:_this->spec.channels];
    st = [[NXPlayStream alloc] initOnDevice:dev withParameters:params];
    [params release];
    h->st_stream = (void *)st;
    if (st == nil) {
        *why = "NXPlayStream did not initialise";
        return 1;
    }
    del = [[OPENSTEPAudioStreamDelegate alloc] init];
    del->owner = h;             /* before setDelegate: nothing can call it yet */
    h->st_delegate = (void *)del;
    [st setDelegate:del];
    e = [st activate];
    if (e != NX_SoundDeviceErrorNone) {
        *why = "activate failed";
        *code = (int)e;
        return 1;
    }
    return 0;
}

static int OPENSTEPAUDIO_SkSubmit(SDL_AudioDevice *_this, int slot, int tag, int *code)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    NXSoundDeviceError e;

    e = [(NXPlayStream *)h->st_stream playBuffer:h->st_ring[slot]
                                            size:h->mixlen tag:tag];
    *code = (int)e;
    return (e != NX_SoundDeviceErrorNone) ? 1 : 0;
}

/* `outstanding` > 0: SoundKit may still read the ring, so the objects are
   left alone after the deactivate, as they always were.  The delegate is
   never released either way -- see StreamClose. */
static void OPENSTEPAUDIO_SkClose(SDL_AudioDevice *_this, int outstanding)
{
    struct SDL_PrivateAudioData *h = _this->hidden;

    if (h->st_stream != NULL) {
        [(NXPlayStream *)h->st_stream deactivate];
    }
    if (outstanding > 0) {
        return;
    }
    if (h->st_stream != NULL) {
        [(NXPlayStream *)h->st_stream setDelegate:nil];
        [(NXPlayStream *)h->st_stream release];
        h->st_stream = NULL;
    }
    if (h->st_dev != NULL) {
        [(NXSoundOut *)h->st_dev release];
        h->st_dev = NULL;
    }
}

/* A submission's outcome, recorded by the SoundKit thread (C).  On a
   refusal the reservation is undone here and the audio thread is told
   through st_async_fail; it calls StreamFail on its next pass, because
   SDL's error state is per thread and the disconnect was always reported
   from there. */
static void OPENSTEPAUDIO_SkSubmitted(SDL_AudioDevice *_this, int slot, int tag, int failed,
                                      OPENSTEP_TraceRow *tr, Uint32 t_pick, Uint32 t_end)
{
    struct SDL_PrivateAudioData *h = _this->hidden;

    mutex_lock(openstep_stream_lock);
    if (failed) {
        if (h->st_tag_of[slot] == tag) {
            h->st_tag_of[slot] = 0;
            --h->st_outstanding;
        }
        ++h->playfailures;
        h->st_async_fail = 1;
    } else {
        ++h->st_submitted;
    }
    if (tr != NULL) {
        tr->sk_pick = t_pick;
        tr->sk_end = t_end;
        tr->sk_done = t_end;            /* nobody waits for a submission any more */
    }
    mutex_unlock(openstep_stream_lock);
}

@interface OPENSTEPAudioSoundKitThread : NSObject
- (void)run:(id)unused;
@end

@implementation OPENSTEPAudioSoundKitThread
- (void)run:(id)unused
{
    (void)unused;
    /* the audio thread's rung: a submission waits on this thread */
    OPENSTEPAUDIO_ThreadPri(&openstep_skpri[0], &openstep_skpri[1], &openstep_skpri[2]);
    openstep_skpri[3] = SDL_SYS_SetThreadPriority(SDL_THREAD_PRIORITY_TIME_CRITICAL);
    OPENSTEPAUDIO_ThreadPri(&openstep_skpri[4], &openstep_skpri[5], NULL);
    for (;;) {
        NSAutoreleasePool *pool;
        OPENSTEP_SkReq r;
        int result = 1, code = 0;
        const char *why = "unknown request";
        Uint32 t_pick, t_end;

        mutex_lock(openstep_sk_lock);
        while (openstep_sk.count == 0) {
            condition_wait(openstep_sk_req, openstep_sk_lock);
        }
        r = openstep_sk.q[openstep_sk.head];
        openstep_sk.head = (openstep_sk.head + 1) % OPENSTEP_SK_FIFO;
        --openstep_sk.count;
        condition_broadcast(openstep_sk_done);      /* room, for a poster that waits */
        mutex_unlock(openstep_sk_lock);
        t_pick = OPENSTEPAUDIO_Now();

        pool = [[NSAutoreleasePool alloc] init];
        switch (r.op) {
        case OPENSTEP_SK_OPEN:
            why = NULL;
            result = OPENSTEPAUDIO_SkOpen(r.dev, &why, &code);
            break;
        case OPENSTEP_SK_SUBMIT:
            result = OPENSTEPAUDIO_SkSubmit(r.dev, r.slot, r.tag, &code);
            why = "playBuffer refused a buffer";
            break;
        case OPENSTEP_SK_CLOSE:
            OPENSTEPAUDIO_SkClose(r.dev, r.arg);
            result = 0;
            why = NULL;
            break;
        default:
            break;
        }
        [pool release];
        t_end = OPENSTEPAUDIO_Now();
        if (r.op == OPENSTEP_SK_SUBMIT) {
            OPENSTEPAUDIO_SkSubmitted(r.dev, r.slot, r.tag, result, r.tr, t_pick, t_end);
        }

        mutex_lock(openstep_sk_lock);
        if (r.ans != NULL) {
            r.ans->result = result;
            r.ans->code = code;
            r.ans->why = why;
        }
        openstep_sk.done = r.seq;
        condition_broadcast(openstep_sk_done);
        mutex_unlock(openstep_sk_lock);
    }
}
@end

/* Start the SoundKit thread once.  The detach is the one Objective-C message
   this path sends from the thread that opens the device. */
static int OPENSTEPAUDIO_SkStart(void)
{
    NSAutoreleasePool *pool;
    OPENSTEPAudioSoundKitThread *t;
    int start;

    if (openstep_sk_lock == NULL || openstep_sk_req == NULL ||
        openstep_sk_done == NULL || openstep_stream_lock == NULL) {
        return -1;
    }
    mutex_lock(openstep_sk_lock);
    start = !openstep_sk_started;
    openstep_sk_started = 1;
    mutex_unlock(openstep_sk_lock);
    if (!start) {
        return 0;
    }
    pool = [[NSAutoreleasePool alloc] init];
    t = [[OPENSTEPAudioSoundKitThread alloc] init];         /* kept for the process's life */
    [NSThread detachNewThreadSelector:@selector(run:) toTarget:t withObject:nil];
    [pool release];
    return 0;
}

/* Put one request on the queue and return its number.  Never called with
   openstep_stream_lock held.  Waits only if the queue is full (32 requests;
   a device has at most OPENSTEP_AUDIO_QUEUE_SLOTS submissions reserved). */
static unsigned long OPENSTEPAUDIO_SkPost(SDL_AudioDevice *_this, int op, int slot, int tag, int arg,
                                          OPENSTEP_TraceRow *tr, struct OPENSTEP_SkAnswer *ans)
{
    OPENSTEP_SkReq *r;
    unsigned long seq;

    if (tr != NULL) tr->sk_enter = OPENSTEPAUDIO_Now();
    mutex_lock(openstep_sk_lock);
    while (openstep_sk.count >= OPENSTEP_SK_FIFO) {
        condition_wait(openstep_sk_done, openstep_sk_lock);
    }
    r = &openstep_sk.q[(openstep_sk.head + openstep_sk.count) % OPENSTEP_SK_FIFO];
    seq = ++openstep_sk.posted;
    r->op = op;
    r->seq = seq;
    r->dev = _this;
    r->slot = slot;
    r->tag = tag;
    r->arg = arg;
    r->tr = tr;
    r->ans = ans;
    ++openstep_sk.count;
    if (tr != NULL) tr->sk_post = OPENSTEPAUDIO_Now();
    condition_signal(openstep_sk_req);
    mutex_unlock(openstep_sk_lock);
    return seq;
}

/* OPEN and CLOSE: post, and wait until the thread has finished this request
   -- and so every one posted before it. */
static int OPENSTEPAUDIO_SkCall(SDL_AudioDevice *_this, int op, int arg, const char **why, int *code)
{
    struct OPENSTEP_SkAnswer a;
    unsigned long seq;

    a.result = 1;
    a.code = 0;
    a.why = NULL;
    seq = OPENSTEPAUDIO_SkPost(_this, op, 0, 0, arg, NULL, &a);
    mutex_lock(openstep_sk_lock);
    while (openstep_sk.done < seq) {
        condition_wait(openstep_sk_done, openstep_sk_lock);
    }
    mutex_unlock(openstep_sk_lock);
    if (why != NULL) *why = a.why;
    if (code != NULL) *code = a.code;
    return a.result;
}

/* A stream that cannot go on stays stopped: SDL gives PlayDevice and
   WaitDevice no way to report failure, and feeding a stuck queue only
   makes more of it.  The core is told the device is gone, which ends the
   callbacks; the application still closes the device as usual. */
static void OPENSTEPAUDIO_StreamFail(_THIS, const char *why)
{
    if (!_this->hidden->st_failed) {
        _this->hidden->st_failed = 1;
        SDL_SetError("OPENSTEP stream audio: %s", why);
        SDL_OpenedAudioDeviceDisconnected(_this);
    }
}

static int OPENSTEPAUDIO_StreamOpen(_THIS)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    const char *why = NULL;
    int i, code = 0;

    for (i = 0; i < OPENSTEP_AUDIO_QUEUE_SLOTS; ++i) {
        vm_address_t a = 0;
        if (vm_allocate(task_self(), &a, h->mixlen, TRUE) != KERN_SUCCESS) {
            return SDL_OutOfMemory();
        }
        h->st_ring[i] = (Uint8 *)a;
        SDL_memset(h->st_ring[i], _this->spec.silence, h->mixlen);
        h->st_tag_of[i] = 0;
    }
    h->st_ring_ok = 1;
    if (OPENSTEPAUDIO_SkStart() < 0) {
        return SDL_SetError("OPENSTEP stream audio: no SoundKit thread");
    }
    if (OPENSTEPAUDIO_SkCall(_this, OPENSTEP_SK_OPEN, 0, &why, &code) != 0) {
        return SDL_SetError("OPENSTEP stream audio: %s (%d)", why ? why : "open failed", code);
    }
    return 0;
}

static void OPENSTEPAUDIO_StreamSubmit(_THIS)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    OPENSTEP_TraceRow *tr = OPENSTEPAUDIO_TraceRow(_this);
    int tag, slot, waited = 0;

    if (h->st_failed) {
        return;
    }
    if (tr != NULL) tr->slot_b = OPENSTEPAUDIO_Now();
    mutex_lock(openstep_stream_lock);
    if (h->st_async_fail) {             /* an earlier submission was refused */
        mutex_unlock(openstep_stream_lock);
        OPENSTEPAUDIO_StreamFail(_this, "playBuffer refused a buffer");
        return;
    }
    tag = h->st_next_tag + 1;
    if (tag <= 0) {
        tag = 1;
    }
    slot = tag % OPENSTEP_AUDIO_QUEUE_SLOTS;
    while (h->st_tag_of[slot] != 0) {
        mutex_unlock(openstep_stream_lock);
        if (waited >= 2000) {
            ++h->st_timeouts;
            OPENSTEPAUDIO_StreamFail(_this, "no buffer came back in 2 s");
            return;
        }
        SDL_Delay(5);
        waited += 5;
        mutex_lock(openstep_stream_lock);
    }
    /* Reserved before the call: the completion can arrive before
       playBuffer returns. */
    h->st_next_tag = tag;
    h->st_tag_of[slot] = tag;
    if (++h->st_outstanding > h->st_out_max) {
        h->st_out_max = h->st_outstanding;
    }
    mutex_unlock(openstep_stream_lock);
    if (tr != NULL) tr->slot_e = OPENSTEPAUDIO_Now();

    SDL_memcpy(h->st_ring[slot], h->mixbuf, h->mixlen);
    /* not waited for: the SoundKit thread plays it and records the outcome */
    (void)OPENSTEPAUDIO_SkPost(_this, OPENSTEP_SK_SUBMIT, slot, tag, 0, tr, NULL);
}

static void OPENSTEPAUDIO_StreamWait(_THIS)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    unsigned int last, comp;
    int out, waited = 0;

    mutex_lock(openstep_stream_lock);
    last = h->st_completed;
    mutex_unlock(openstep_stream_lock);
    for (;;) {
        int refused;
        mutex_lock(openstep_stream_lock);
        out = h->st_outstanding;
        comp = h->st_completed;
        refused = h->st_async_fail;
        mutex_unlock(openstep_stream_lock);
        if (refused) {
            OPENSTEPAUDIO_StreamFail(_this, "playBuffer refused a buffer");
            return;
        }
        if (out < h->ahead || h->st_failed) {
            return;
        }
        if (comp != last) {
            last = comp;
            waited = 0;
        }
        if (waited >= 2000) {
            ++h->st_timeouts;
            OPENSTEPAUDIO_StreamFail(_this, "no completion in 2 s");
            return;
        }
        SDL_Delay(5);
        waited += 5;
    }
}

/* Returns 1 when everything was handed back and freed, 0 when SoundKit may
   still hold the ring -- then nothing is freed, and the caller must not
   free the private data either.  The delegate is never released: once
   setDelegate:nil has been sent, SoundKit's reply thread may still hold a
   pointer it read before, and a released delegate is the "sent to freed
   object" failure this path already had once.  It is told its owner is
   gone, under the lock it reads the owner with, and kept. */
static int OPENSTEPAUDIO_StreamClose(_THIS)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    int waited = 0, out = 0, i;

    if (openstep_stream_lock != NULL) {
        for (;;) {
            mutex_lock(openstep_stream_lock);
            out = h->st_outstanding;
            mutex_unlock(openstep_stream_lock);
            if (out <= 0 || waited >= 2000) break;
            SDL_Delay(5);
            waited += 5;
        }
    }
    if (openstep_sk_started && (h->st_stream != NULL || h->st_dev != NULL)) {
        (void)OPENSTEPAUDIO_SkCall(_this, OPENSTEP_SK_CLOSE, out, NULL, NULL);
    }
    if (h->st_delegate != NULL) {
        mutex_lock(openstep_stream_lock);
        ((OPENSTEPAudioStreamDelegate *)h->st_delegate)->owner = NULL;
        mutex_unlock(openstep_stream_lock);
        h->st_delegate = NULL;
    }
    if (out > 0) {
        return 0;
    }
    for (i = 0; i < OPENSTEP_AUDIO_QUEUE_SLOTS; ++i) {
        if (h->st_ring[i] != NULL) {
            vm_deallocate(task_self(), (vm_address_t)h->st_ring[i], h->mixlen);
            h->st_ring[i] = NULL;
        }
    }
    return 1;
}

static int OPENSTEPAUDIO_OpenDevice(_THIS, const char *devname)
{
    (void)devname;
    if (_this->iscapture) {
        return SDL_Unsupported();
    }
    /*
     * ONE DEVICE FORMAT, ALWAYS.  The backend used to pass 22050 through
     * and to accept mono, and the SDL core would convert to whatever came
     * out.  It costs nothing to convert here instead, and it buys the one
     * thing this backend cannot do without: the kernel's descriptor is
     * 8192 BYTES, so its duration -- and with it the mixer's lead and the
     * reserve -- depends on the device's byte rate.  At 22050 mono a
     * descriptor is 185.8 ms instead of 46.44, and the reserve arithmetic
     * below would be wrong by more than the reserve.  Fixing the device
     * format is what makes the measured numbers the shipped numbers.
     */
    _this->spec.freq = 44100;
    _this->spec.channels = 2;
    _this->spec.format = AUDIO_S16MSB;
    /*
     * A sixteenth of a second a buffer, six of them queued: the same 375 ms
     * of latency the library has shipped since openstep.3, with two and a
     * half times the reserve.  See the header for why smaller buffers win
     * at a fixed latency, and docs/measurements/README.md for the measurements.
     */
    /*
     * A SIXTEENTH OF A SECOND, unless told otherwise.
     *
     * SDL_OPENSTEP_BUFFER_MS exists because the reserve and the number of
     * calls to SNDStartPlaying are the same knob turned opposite ways.
     * libsound will not start a seventh concurrent sound, so the queue is
     * six sounds whatever their length -- but a longer sound holds more
     * audio, and the stalls being chased are all inside that call:
     *
     *    62 ms x 6   375 ms latency,  ~240-280 ms reserve, 16 calls/s
     *    83 ms x 6   500 ms latency,  ~345-385 ms reserve, 12 calls/s
     *   100 ms x 6   600 ms latency,  ~428-468 ms reserve, 10 calls/s
     *
     * The measured stalls run to about 500 ms, so buying reserve buys
     * absorption -- at the price of latency, which a game pays for in
     * sound effects that lag the action.  Default unchanged; this is here
     * so the trade can be measured before anybody commits to it.
     */
    {
        const char *e = SDL_getenv("SDL_OPENSTEP_BUFFER_MS");
        int ms = e != NULL ? SDL_atoi(e) : 0;
        if (ms < 20 || ms > 250) {
            _this->spec.samples = (Uint16)(_this->spec.freq / 16);
        } else {
            _this->spec.samples = (Uint16)((_this->spec.freq * ms) / 1000);
        }
    }
    SDL_CalculateAudioSpec(&_this->spec);

    _this->hidden = (struct SDL_PrivateAudioData *)SDL_calloc(1, sizeof(*_this->hidden));
    if (_this->hidden == NULL) {
        return SDL_OutOfMemory();
    }
    _this->hidden->mixlen = _this->spec.size;
    _this->hidden->mixbuf = (Uint8 *)SDL_malloc(_this->hidden->mixlen);
    if (_this->hidden->mixbuf == NULL) {
        SDL_free(_this->hidden);
        _this->hidden = NULL;
        return SDL_OutOfMemory();
    }
    SDL_memset(_this->hidden->mixbuf, _this->spec.silence, _this->hidden->mixlen);
    /*
     * The pool, and the fault taken now rather than later.  Every page is
     * written here, at open, so the first submission of each slot is not
     * the one that has to find pages while the disk is busy.  A failure
     * to allocate is not fatal: the backend falls back to what it did
     * before, one malloc per buffer.
     */
    {
        const char *e = SDL_getenv("SDL_OPENSTEP_BUFFER_POOL");
        int want = (e == NULL) || (SDL_atoi(e) != 0);
        Uint32 cap = _this->hidden->mixlen;
        int i;

        if (cap < (Uint32)OPENSTEP_AUDIO_PRIMER_BYTES) {
            cap = (Uint32)OPENSTEP_AUDIO_PRIMER_BYTES;
        }
        if (want) {
            for (i = 0; i < OPENSTEP_AUDIO_QUEUE_SLOTS; ++i) {
                _this->hidden->pool[i] =
                    SDL_malloc(sizeof(SNDSoundStruct) + cap);
                if (_this->hidden->pool[i] == NULL) {
                    break;
                }
                SDL_memset(_this->hidden->pool[i], 0,
                           sizeof(SNDSoundStruct) + cap);
            }
            if (i == OPENSTEP_AUDIO_QUEUE_SLOTS) {
                _this->hidden->pooled = 1;
            } else {
                while (i-- > 0) {
                    SDL_free(_this->hidden->pool[i]);
                    _this->hidden->pool[i] = NULL;
                }
            }
        }
    }
    {
        const char *e = SDL_getenv("SDL_OPENSTEP_QUEUE_AHEAD");
        int a = e != NULL ? SDL_atoi(e) : 0;
        if (a < 2 || a > OPENSTEP_AUDIO_QUEUE_SLOTS - 1) {
            a = OPENSTEP_AUDIO_QUEUE_AHEAD;
        }
        _this->hidden->ahead = a;
        e = SDL_getenv("SDL_OPENSTEP_HELPER_PRIORITY");
        _this->hidden->raise_helpers = (e != NULL && SDL_atoi(e) != 0);
    }
    _this->hidden->delay_ms = (_this->spec.samples * 1000) / _this->spec.freq;
    if (_this->hidden->delay_ms == 0) {
        _this->hidden->delay_ms = 1;
    }
    {
        /* The stream is the default; SDL_OPENSTEP_AUDIO_API=sound keeps the
           per-sound queue for comparison or as a way back. */
        const char *e = SDL_getenv("SDL_OPENSTEP_AUDIO_API");
        if (e == NULL || SDL_strcmp(e, "sound") != 0) {
            _this->hidden->use_stream = 1;
            _this->hidden->trace_cur = -1;
            if (SDL_getenv("SDL_OPENSTEP_AUDIO_TRACE") != NULL) {
                /* before the stream exists: the delegate may write ctrace at once */
                _this->hidden->trace = SDL_calloc(OPENSTEP_TRACE_ROWS, sizeof(OPENSTEP_TraceRow));
                _this->hidden->ctrace = SDL_calloc(OPENSTEP_TRACE_ROWS, sizeof(OPENSTEP_CompRow));
            }
            if (OPENSTEPAUDIO_StreamOpen(_this) < 0) {
                return -1;          /* CloseDevice cleans up what was made */
            }
        }
    }
    return 0;
}

static Uint8 *OPENSTEPAUDIO_GetDeviceBuf(_THIS)
{
    return _this->hidden->mixbuf;
}

/* Where one Enqueue spent its time.  Accumulated across the submission --
 * PlayDevice can enqueue twice, primer and buffer -- and kept two ways, for
 * the reason the header gives: the breakdown of the worst submission, and
 * the worst each part ever reached alone. */
static void OPENSTEPAUDIO_Parts(_THIS, Uint32 drain, Uint32 alloc,
                                Uint32 copy, Uint32 start)
{
    Uint32 p[4];
    int i;

    p[0] = drain; p[1] = alloc; p[2] = copy; p[3] = start;
    for (i = 0; i < 4; ++i) {
        _this->hidden->play_parts[i] += p[i];
        if (p[i] > _this->hidden->part_max[i]) {
            _this->hidden->part_max[i] = p[i];
        }
    }
}

/* One sound queued, the way this backend has always queued one: its own
 * SNDSoundStruct, played with preempt 0 so SoundKit keeps them in order.
 * `data` NULL means a region of silence, which is what the primer is.
 * Reclaims a slot first, because PlayDevice can now enqueue twice. */
static void OPENSTEPAUDIO_Enqueue(_THIS, const Uint8 *data, Uint32 len)
{
    SNDSoundStruct *sound;
    int slot;
    int error;
    Uint32 t0, t1, t2, t3, t4;

    t0 = OPENSTEPAUDIO_Now();
    if (_this->hidden->count == OPENSTEP_AUDIO_QUEUE_SLOTS) {
        OPENSTEPAUDIO_DrainOne(_this);
    }
    t1 = OPENSTEPAUDIO_Now();
    /* The slot this sound will occupy, decided before the buffer is
       chosen because the pooled buffer belongs to the slot.  head and
       count do not move between here and the store below. */
    slot = (_this->hidden->head + _this->hidden->count)
         % OPENSTEP_AUDIO_QUEUE_SLOTS;
    if (_this->hidden->pooled) {
        sound = (SNDSoundStruct *)_this->hidden->pool[slot];
    } else {
        sound = (SNDSoundStruct *)SDL_malloc(sizeof(*sound) + len);
    }
    t2 = OPENSTEPAUDIO_Now();
    if (sound == NULL) {
        OPENSTEPAUDIO_Parts(_this, t1 - t0, t2 - t1, 0, 0);
        SDL_OutOfMemory();
        return;
    }
    sound->magic = SND_MAGIC;
    sound->dataLocation = sizeof(*sound);
    sound->dataSize = (int)len;
    sound->dataFormat = SND_FORMAT_LINEAR_16;
    sound->samplingRate = _this->spec.freq;
    sound->channelCount = _this->spec.channels;
    if (data != NULL) {
        SDL_memcpy(((Uint8 *)sound) + sizeof(*sound), data, len);
    } else {
        SDL_memset(((Uint8 *)sound) + sizeof(*sound), _this->spec.silence, len);
    }

    t3 = OPENSTEPAUDIO_Now();

    /* What libsound's admission check will be looking at.  Taken here, at
       the call, not at PlayDevice entry: the primer enqueues first on the
       very first buffer, so the two are not the same number. */
    _this->hidden->count_at_start = _this->hidden->count;
    ++_this->hidden->next_tag;
    if (_this->hidden->next_tag <= 0) {
        _this->hidden->next_tag = 1;
    }
    error = SNDStartPlaying(sound, _this->hidden->next_tag, 0, 0, SND_NULL_FUN, SND_NULL_FUN);
    t4 = OPENSTEPAUDIO_Now();
    OPENSTEPAUDIO_Parts(_this, t1 - t0, t2 - t1, t3 - t2, t4 - t3);
    if (error != SND_ERR_NONE) {
        if (!_this->hidden->pooled) {
            SDL_free(sound);
        }
        ++_this->hidden->playfailures;
        SDL_SetError("OPENSTEP SoundKit play failed (%d)", error);
        return;
    }
    _this->hidden->sounds[slot] = sound;
    _this->hidden->tags[slot] = _this->hidden->next_tag;
    ++_this->hidden->count;
}

static void OPENSTEPAUDIO_PlayDevice(_THIS)
{
    Uint32 t_in = OPENSTEPAUDIO_Now();
    Uint32 cpu_in = OPENSTEPAUDIO_CpuUs(_this);
    Uint32 spent, cpu_spent;
    Uint32 pg_in, ft_in, pg_out, ft_out;
    int i;

    OPENSTEPAUDIO_Events(&pg_in, &ft_in);
    if (_this->hidden->pagein_at_open == 0) {
        _this->hidden->pagein_at_open = pg_in;
        _this->hidden->fault_at_open = ft_in;
    }

    for (i = 0; i < 4; ++i) {
        _this->hidden->play_parts[i] = 0;
    }
    if (_this->hidden->t_open == 0) {
        _this->hidden->t_open = t_in;
    } else if (_this->hidden->t_wait_ret != 0) {
        /* The interval this whole investigation now turns on: everything
         * between "the device asked for more" and "we gave it more" --
         * and, beside it, how much of that interval this thread was
         * actually running. */
        OPENSTEPAUDIO_Record(_this, t_in - _this->hidden->t_wait_ret,
                             cpu_in - _this->hidden->cpu_wait_ret);
    }
    ++_this->hidden->nbuf;
    /* The first buffer the core did not fill with silence: the game's
       first song, dated on the same clock as the gaps and submissions. */
    if (!_this->hidden->unpaused && !SDL_AtomicGet(&_this->paused)) {
        _this->hidden->unpaused = 1;
        _this->hidden->unpause_when = (t_in - _this->hidden->t_open) / 1000U;
        _this->hidden->unpause_nbuf = _this->hidden->nbuf;
    }
    /* An empty queue after the first buffer means the device ran dry --
     * counted, and said once at close, because a short repeated gap is
     * hard to judge by ear. */
    if (_this->hidden->use_stream) {
        /* nothing of ours in flight: a software observation, counted apart */
        if (_this->hidden->started && _this->hidden->st_outstanding == 0) {
            ++_this->hidden->st_empty;
        }
        if (_this->hidden->trace != NULL) {
            struct SDL_PrivateAudioData *h = _this->hidden;
            OPENSTEP_TraceRow *tr;
            h->trace_cur = (int)(h->trace_n % (unsigned int)OPENSTEP_TRACE_ROWS);
            ++h->trace_n;
            tr = &((OPENSTEP_TraceRow *)h->trace)[h->trace_cur];
            SDL_memset(tr, 0, sizeof(*tr));
            tr->entry = t_in;
            tr->wait_ret_prev = h->t_wait_ret;
            mutex_lock(openstep_stream_lock);
            tr->out_entry = h->st_outstanding;
            tr->comp_entry = h->st_completed;
            mutex_unlock(openstep_stream_lock);
        }
    } else if (_this->hidden->started && _this->hidden->count == 0) {
        ++_this->hidden->underruns;
    }
    _this->hidden->started = 1;
    /*
     * THE PRIMER, AND WHY IT IS HERE RATHER THAN IN OpenDevice.
     *
     * The kernel starts its DMA on the first region it is given, and it
     * decides then -- once, for the life of that DMA -- how many
     * descriptors ahead of the play point its mixer will run.  A short
     * first region means a short lead, and the lead comes straight off
     * the reserve.  So the first thing it is given is one descriptor of
     * silence rather than a whole buffer.
     *
     * Not in OpenDevice, because a device is opened paused: the primer
     * would drain, the DMA would stop, and the lead would be picked again
     * from whatever arrived next.  Here it is followed immediately by a
     * real buffer, and both are in flight before the queue could empty.
     *
     * The flag is set BEFORE the attempt, so a failed primer is not
     * retried on every buffer; a failure costs the reserve it would have
     * bought and nothing else.
     */
    if (_this->hidden->use_stream) {
        OPENSTEPAUDIO_StreamSubmit(_this);     /* no primer: see the stream path */
    } else {
        if (!_this->hidden->primed) {
            _this->hidden->primed = 1;
            OPENSTEPAUDIO_Enqueue(_this, NULL, (Uint32)OPENSTEP_AUDIO_PRIMER_BYTES);
        }
        OPENSTEPAUDIO_Enqueue(_this, _this->hidden->mixbuf, _this->hidden->mixlen);
    }
    /* per-sound only: its target is libsound's reply thread, which exists
       once a sound has started -- a stream submission has not necessarily
       reached SoundKit when this returns */
    if (!_this->hidden->hooked && !_this->hidden->use_stream) {
        _this->hidden->hooked = 1;
        if (_this->hidden->raise_helpers) {
            OPENSTEPAUDIO_RaiseHelpers(_this);
        }
    }
    spent = OPENSTEPAUDIO_Now() - t_in;
    cpu_spent = OPENSTEPAUDIO_CpuUs(_this) - cpu_in;
    OPENSTEPAUDIO_RecordSubmit(_this, spent);
    if (spent >= (Uint32)OPENSTEP_AUDIO_LONGSUB_US) {
        Uint32 n = _this->hidden->nlongsub;
        if (n < (Uint32)OPENSTEP_AUDIO_LONGSUB_SLOTS) {
            _this->hidden->longsub_when[n] =
                (t_in - _this->hidden->t_open) / 1000U;
            _this->hidden->longsub_us[n] = spent;
            _this->hidden->longsub_start[n] = _this->hidden->play_parts[3];
            _this->hidden->longsub_nbuf[n] = _this->hidden->nbuf;
            _this->hidden->longsub_count[n] =
                (Uint32)_this->hidden->count_at_start;
            OPENSTEPAUDIO_Events(&pg_out, &ft_out);
            _this->hidden->longsub_pagein[n] = pg_out - pg_in;
            _this->hidden->longsub_fault[n] = ft_out - ft_in;
        }
        ++_this->hidden->nlongsub;
    }
    if (spent > _this->hidden->play_max) {
        _this->hidden->play_max = spent;
        _this->hidden->play_max_when = (t_in - _this->hidden->t_open) / 1000U;
        _this->hidden->play_max_nbuf = _this->hidden->nbuf;
        _this->hidden->play_max_cpu = cpu_spent;
        for (i = 0; i < 4; ++i) {
            _this->hidden->play_max_parts[i] = _this->hidden->play_parts[i];
        }
    }
}

static void OPENSTEPAUDIO_WaitDevice(_THIS)
{
    if (_this->hidden->use_stream) {
        OPENSTEP_TraceRow *tr = OPENSTEPAUDIO_TraceRow(_this);
        if (tr != NULL) tr->wait_b = OPENSTEPAUDIO_Now();
        OPENSTEPAUDIO_StreamWait(_this);
        if (tr != NULL) tr->wait_e = OPENSTEPAUDIO_Now();
    } else if (_this->hidden->count >= _this->hidden->ahead) {
        OPENSTEPAUDIO_DrainOne(_this);
    }
    /* Taken on every exit, drained or not: the core calls PlayDevice next
     * either way, and the interval between the two is what is being
     * measured. */
    _this->hidden->cpu_wait_ret = OPENSTEPAUDIO_CpuUs(_this);
    _this->hidden->t_wait_ret = OPENSTEPAUDIO_Now();
}

/* The core calls this on the callback thread, once, after it has asked for
 * a priority and before the first buffer -- the only place that knows which
 * thread ID the lock accounting should follow. */
static void OPENSTEPAUDIO_ThreadInit(_THIS)
{
    (void)_this;
    OPENSTEP_MutexWatchThread(SDL_ThreadID());
}

/*
 * Said once, when the device closes, and never while it is playing: an
 * IOLog in the wrong place has already distorted this investigation twice.
 *
 * AND ONLY WHEN ASKED.  These eight lines are how the audio path was
 * measured and they should stay in the library -- the next person to hear
 * a stutter should not have to rebuild it to find out why.  But a library
 * that prints a page of histograms every time a game exits is a library
 * that gets its logging turned off wholesale, so it is off unless
 * SDL_OPENSTEP_AUDIO_REPORT says otherwise.  Underruns and play failures
 * are reported regardless (CloseDevice does that); those are faults, not
 * measurements.
 */
static void OPENSTEPAUDIO_Report(_THIS)
{
    static const char *edge[8] = { "  <25", " <50", "<100", "<150",
                                   "<250", "<375", "<500", ">=500" };
    Uint32 i;

    if (_this->hidden->nbuf == 0) return;
    if (SDL_getenv("SDL_OPENSTEP_AUDIO_REPORT") == NULL) return;
    SDL_Log("OPENSTEP audio: %u buffers of %u frames, %u queued;"
            " worst wait %u ms, worst submit %u ms at %u.%03u s (buffer %u)",
            (unsigned)_this->hidden->nbuf, (unsigned)_this->spec.samples,
            (unsigned)_this->hidden->ahead,
            (unsigned)(_this->hidden->wait_max / 1000U),
            (unsigned)(_this->hidden->play_max / 1000U),
            (unsigned)(_this->hidden->play_max_when / 1000U),
            (unsigned)(_this->hidden->play_max_when % 1000U),
            (unsigned)_this->hidden->play_max_nbuf);
    /* The four parts of that worst submission, and the worst each part
     * ever reached on its own.  us and not ms: copy is about a
     * millisecond and rounding it to zero would be rounding away the
     * control. */
    SDL_Log("OPENSTEP audio: worst submit = drain %u + malloc %u + copy %u"
            " + start %u us, %u us of it on processor",
            (unsigned)_this->hidden->play_max_parts[0],
            (unsigned)_this->hidden->play_max_parts[1],
            (unsigned)_this->hidden->play_max_parts[2],
            (unsigned)_this->hidden->play_max_parts[3],
            (unsigned)_this->hidden->play_max_cpu);
    SDL_Log("OPENSTEP audio: queue ahead %d, helper priority %s (%d raised)",
            _this->hidden->ahead,
            _this->hidden->raise_helpers ? "on" : "off",
            _this->hidden->helpers_raised);
    {
        Uint32 pg = 0, ft = 0;
        if (OPENSTEPAUDIO_Events(&pg, &ft)) {
            SDL_Log("OPENSTEP audio: task paged in %u times, %u faults",
                    (unsigned)(pg - _this->hidden->pagein_at_open),
                    (unsigned)(ft - _this->hidden->fault_at_open));
        } else {
            SDL_Log("OPENSTEP audio: TASK_EVENTS_INFO unavailable on this"
                    " kernel -- paging was NOT measured");
        }
    }
    SDL_Log("OPENSTEP audio: %u frame buffers, %s",
            (unsigned)_this->spec.samples,
            _this->hidden->pooled ? "pooled (allocated once)"
                                  : "one malloc per submission");
    if (_this->hidden->unpaused) {
        SDL_Log("OPENSTEP audio: unpaused (first song) at %u.%03u s,"
                " buffer %u",
                (unsigned)(_this->hidden->unpause_when / 1000U),
                (unsigned)(_this->hidden->unpause_when % 1000U),
                (unsigned)_this->hidden->unpause_nbuf);
    } else {
        SDL_Log("OPENSTEP audio: never unpaused");
    }
    SDL_Log("OPENSTEP audio: worst ever drain %u, malloc %u, copy %u,"
            " start %u us",
            (unsigned)_this->hidden->part_max[0],
            (unsigned)_this->hidden->part_max[1],
            (unsigned)_this->hidden->part_max[2],
            (unsigned)_this->hidden->part_max[3]);
    {
        static const char *sedge[8] = { "<0.5", "  <1", "  <2", "  <5",
                                        " <25", "<100", "<250", ">=250" };
        static const char *wedge[8] = { " <25", " <50", " <62", " <75",
                                        "<100", "<150", "<250", ">=250" };
        char line[160];
        int n = 0;

        n = SDL_snprintf(line, sizeof(line), "OPENSTEP audio: submit ms ");
        for (i = 0; i < 8; ++i) {
            n += SDL_snprintf(line + n, sizeof(line) - n, " %s:%u",
                              sedge[i], (unsigned)_this->hidden->submit_hist[i]);
        }
        SDL_Log("%s", line);
        n = SDL_snprintf(line, sizeof(line), "OPENSTEP audio: SNDWait ms ");
        for (i = 0; i < 8; ++i) {
            n += SDL_snprintf(line + n, sizeof(line) - n, " %s:%u",
                              wedge[i], (unsigned)_this->hidden->wait_hist[i]);
        }
        SDL_Log("%s", line);
    }
    /* Every submission over 25 ms, with the things that would name a
       cause.  Capped at the slot count; the counter says how many there
       really were. */
    if (_this->hidden->nlongsub > 0) {
        Uint32 shown = _this->hidden->nlongsub;
        if (shown > (Uint32)OPENSTEP_AUDIO_LONGSUB_SLOTS) {
            shown = (Uint32)OPENSTEP_AUDIO_LONGSUB_SLOTS;
        }
        SDL_Log("OPENSTEP audio: %u slow submission(s) over 25 ms,"
                " first %u:", (unsigned)_this->hidden->nlongsub,
                (unsigned)shown);
        for (i = 0; i < shown; ++i) {
            SDL_Log("OPENSTEP audio:   at %u.%03u s buffer %u: %u ms,"
                    " SNDStartPlaying %u ms, queue held %u,"
                    " pageins %u, faults %u",
                    (unsigned)(_this->hidden->longsub_when[i] / 1000U),
                    (unsigned)(_this->hidden->longsub_when[i] % 1000U),
                    (unsigned)_this->hidden->longsub_nbuf[i],
                    (unsigned)(_this->hidden->longsub_us[i] / 1000U),
                    (unsigned)(_this->hidden->longsub_start[i] / 1000U),
                    (unsigned)_this->hidden->longsub_count[i],
                    (unsigned)_this->hidden->longsub_pagein[i],
                    (unsigned)_this->hidden->longsub_fault[i]);
        }
    }
    {
        Uint32 acq = 0, lus = 0, lmax = 0;
        OPENSTEP_MutexWatchStats(&acq, &lus, &lmax);
        SDL_Log("OPENSTEP audio: this thread base priority %d, current %d,"
                " max %d, depressed %d",
                _this->hidden->base_pri, _this->hidden->cur_pri,
                _this->hidden->max_pri, _this->hidden->depressed);
        /* The whole point of these three numbers: if the gaps above are
           spent here, the mutex is the problem; if they are not, the
           scheduler is. */
        SDL_Log("OPENSTEP audio: SDL mutexes %s; %u acquisitions took"
                " %u ms in total, worst %u ms",
                OPENSTEP_MutexIsBlocking() ? "block" : "yield",
                (unsigned)acq, (unsigned)(lus / 1000U),
                (unsigned)(lmax / 1000U));
    }
    SDL_Log("OPENSTEP audio: refill gap ms  %s:%u %s:%u %s:%u %s:%u"
            " %s:%u %s:%u %s:%u %s:%u   worst %u ms",
            edge[0], (unsigned)_this->hidden->gap_hist[0],
            edge[1], (unsigned)_this->hidden->gap_hist[1],
            edge[2], (unsigned)_this->hidden->gap_hist[2],
            edge[3], (unsigned)_this->hidden->gap_hist[3],
            edge[4], (unsigned)_this->hidden->gap_hist[4],
            edge[5], (unsigned)_this->hidden->gap_hist[5],
            edge[6], (unsigned)_this->hidden->gap_hist[6],
            edge[7], (unsigned)_this->hidden->gap_hist[7],
            (unsigned)(_this->hidden->gap_max / 1000U));
    if (_this->hidden->nlong != 0) {
        Uint32 shown = _this->hidden->nlong;
        if (shown > (Uint32)OPENSTEP_AUDIO_LONG_SLOTS)
            shown = (Uint32)OPENSTEP_AUDIO_LONG_SLOTS;
        /* The threshold comes from the constant, not from a sentence
           somebody has to remember to edit: it was lowered from 100 ms to
           25 and this line would otherwise have gone on claiming 100. */
        SDL_Log("OPENSTEP audio: %u gaps over %u ms; first %u, as"
                " (seconds into the run, gap ms, cpu ms in that gap):",
                (unsigned)_this->hidden->nlong,
                (unsigned)(OPENSTEP_AUDIO_LONG_US / 1000),
                (unsigned)shown);
        for (i = 0; i < shown; i++) {
            SDL_Log("OPENSTEP audio:   %u.%03u  gap %u  cpu %u",
                    (unsigned)(_this->hidden->long_when[i] / 1000U),
                    (unsigned)(_this->hidden->long_when[i] % 1000U),
                    (unsigned)(_this->hidden->long_gap[i] / 1000U),
                    (unsigned)(_this->hidden->long_cpu[i] / 1000U));
        }
    }
}

/* SDL_OPENSTEP_AUDIO_TRACE: write this device's traces, oldest row first.
   Runs on the closing thread after StreamClose, when the delegate has
   already been told its owner is gone -- nothing else touches the rings. */
static void OPENSTEPAUDIO_TraceWrite(_THIS)
{
    struct SDL_PrivateAudioData *h = _this->hidden;
    const char *path = SDL_getenv("SDL_OPENSTEP_AUDIO_TRACE");
    char name[1024];
    FILE *f;
    unsigned int i, n, first;

    if (path == NULL || h->trace == NULL || h->ctrace == NULL) {
        return;
    }
    SDL_snprintf(name, sizeof(name), "%s.%d.%d", path, (int)getpid(), ++openstep_trace_seq);
    f = fopen(name, "w");
    if (f == NULL) {
        return;
    }
    fprintf(f, "# openstep-sdl2 stream trace 1: freq %d channels %d samples %d mixlen %lu ahead %d t_open %lu\n",
            _this->spec.freq, (int)_this->spec.channels, (int)_this->spec.samples,
            (unsigned long)h->mixlen, h->ahead, (unsigned long)h->t_open);
    fprintf(f, "# soundkit-thread before base %d cur %d max %d, request rc %d, after base %d cur %d;"
               " reply-thread base %d cur %d max %d\n",
            openstep_skpri[0], openstep_skpri[1], openstep_skpri[2], openstep_skpri[3],
            openstep_skpri[4], openstep_skpri[5], openstep_rppri[0], openstep_rppri[1], openstep_rppri[2]);
    fprintf(f, "# R n entry wait_ret_prev out comp slot_b slot_e sk_enter sk_post sk_pick sk_end sk_done wait_b wait_e\n");
    n = h->trace_n < (unsigned int)OPENSTEP_TRACE_ROWS ? h->trace_n : (unsigned int)OPENSTEP_TRACE_ROWS;
    first = h->trace_n - n;
    for (i = 0; i < n; ++i) {
        const OPENSTEP_TraceRow *r = &((OPENSTEP_TraceRow *)h->trace)[(first + i) % (unsigned int)OPENSTEP_TRACE_ROWS];
        fprintf(f, "R %u %lu %lu %d %u %lu %lu %lu %lu %lu %lu %lu %lu %lu\n", first + i,
                (unsigned long)r->entry, (unsigned long)r->wait_ret_prev, r->out_entry, r->comp_entry,
                (unsigned long)r->slot_b, (unsigned long)r->slot_e,
                (unsigned long)r->sk_enter, (unsigned long)r->sk_post, (unsigned long)r->sk_pick,
                (unsigned long)r->sk_end, (unsigned long)r->sk_done,
                (unsigned long)r->wait_b, (unsigned long)r->wait_e);
    }
    fprintf(f, "# C n when tag\n");
    n = h->ctrace_n < (unsigned int)OPENSTEP_TRACE_ROWS ? h->ctrace_n : (unsigned int)OPENSTEP_TRACE_ROWS;
    first = h->ctrace_n - n;
    for (i = 0; i < n; ++i) {
        const OPENSTEP_CompRow *c = &((OPENSTEP_CompRow *)h->ctrace)[(first + i) % (unsigned int)OPENSTEP_TRACE_ROWS];
        fprintf(f, "C %u %lu %d\n", first + i, (unsigned long)c->when, c->tag);
    }
    fprintf(f, "# end rows %u completions %u\n", h->trace_n, h->ctrace_n);
    fclose(f);
}

static void OPENSTEPAUDIO_CloseDevice(_THIS)
{
    if (_this->hidden != NULL && _this->hidden->use_stream) {
        struct SDL_PrivateAudioData *h = _this->hidden;
        int freed = OPENSTEPAUDIO_StreamClose(_this);
        OPENSTEPAUDIO_TraceWrite(_this);
        /* the delegate's owner is NULL now (StreamClose), so the reply
           thread no longer writes ctrace */
        SDL_free(h->trace);
        h->trace = NULL;
        SDL_free(h->ctrace);
        h->ctrace = NULL;
        if (SDL_getenv("SDL_OPENSTEP_AUDIO_REPORT") != NULL) {
            OPENSTEPAUDIO_Report(_this);
            SDL_Log("OPENSTEP audio: API stream (NXPlayStream) -- the SNDWait,"
                    " SNDStartPlaying, primer, malloc and helper lines above"
                    " belong to the per-sound path and do not apply, and a"
                    " submission time above is the queueing only");
            SDL_Log("OPENSTEP audio: stream submitted %u, started %u, completed %u,"
                    " most in flight %d, stale callbacks %u, SoundKit underruns %u,"
                    " queue seen empty %u, timeouts %u, failed %d, freed %d",
                    h->st_submitted, h->st_started, h->st_completed, h->st_out_max,
                    h->st_stale_cb, h->st_underrun_cb, h->st_empty, h->st_timeouts,
                    h->st_failed, freed);
        }
        if (h->playfailures != 0 || h->st_timeouts != 0 || h->st_underrun_cb != 0) {
            SDL_LogError(SDL_LOG_CATEGORY_AUDIO,
                         "OPENSTEP audio: stream %d play failures, %u timeouts, %u underruns",
                         h->playfailures, h->st_timeouts, h->st_underrun_cb);
        }
        {
            int i;
            for (i = 0; i < OPENSTEP_AUDIO_QUEUE_SLOTS; ++i) {
                SDL_free(h->pool[i]);
                h->pool[i] = NULL;
            }
        }
        if (freed) {
            SDL_free(h->mixbuf);
            SDL_free(h);
        }
        /* not freed: SoundKit may still read the ring and call the delegate,
           which points at `h` -- leaking both is the safe outcome */
        _this->hidden = NULL;
        return;
    }
    if (_this->hidden != NULL) {
        OPENSTEPAUDIO_Report(_this);
        /*
         * A FAULT, AT ERROR LEVEL, AND NOTHING OTHERWISE.
         *
         * SDL_Log is the application's INFO channel, and a library has no
         * business writing there: a normal run of a game printed a line
         * of ours on the way out.  These two counters are the only things
         * the backend has to say uninvited -- a play that SoundKit
         * refused, or a queue that actually ran dry -- and they belong in
         * the audio category at error level, where a program that does
         * not want them can turn them off by category.  Everything else
         * is measurement and waits for SDL_OPENSTEP_AUDIO_REPORT.
         */
        if (_this->hidden->underruns != 0 || _this->hidden->playfailures != 0) {
            SDL_LogError(SDL_LOG_CATEGORY_AUDIO,
                         "OPENSTEP audio: %d underruns, %d play failures",
                         _this->hidden->underruns,
                         _this->hidden->playfailures);
        }
        while (_this->hidden->count > 0) {
            OPENSTEPAUDIO_DrainOne(_this);
        }
        /* After the drain, not before: DrainOne waits on sounds that are
           still playing out of these very buffers. */
        {
            int i;
            for (i = 0; i < OPENSTEP_AUDIO_QUEUE_SLOTS; ++i) {
                SDL_free(_this->hidden->pool[i]);
                _this->hidden->pool[i] = NULL;
            }
        }
        SDL_free(_this->hidden->mixbuf);
        SDL_free(_this->hidden);
        _this->hidden = NULL;
    }
}

static SDL_bool OPENSTEPAUDIO_Init(SDL_AudioDriverImpl *impl)
{
    /* The stream path's locks, made once and never freed: the SoundKit
       thread they serve lives as long as the process, and this runs again
       at every SDL_AudioInit.  Plain C -- no Objective-C here. */
    if (openstep_stream_lock == NULL) openstep_stream_lock = mutex_alloc();
    if (openstep_sk_lock == NULL) openstep_sk_lock = mutex_alloc();
    if (openstep_sk_req == NULL) openstep_sk_req = condition_alloc();
    if (openstep_sk_done == NULL) openstep_sk_done = condition_alloc();
    impl->ThreadInit = OPENSTEPAUDIO_ThreadInit;
    impl->OpenDevice = OPENSTEPAUDIO_OpenDevice;
    impl->WaitDevice = OPENSTEPAUDIO_WaitDevice;
    impl->PlayDevice = OPENSTEPAUDIO_PlayDevice;
    impl->GetDeviceBuf = OPENSTEPAUDIO_GetDeviceBuf;
    impl->CloseDevice = OPENSTEPAUDIO_CloseDevice;
    impl->OnlyHasDefaultOutputDevice = SDL_TRUE;
    impl->SupportsNonPow2Samples = SDL_TRUE;
    return SDL_TRUE;
}

AudioBootStrap OPENSTEPAUDIO_bootstrap = {
    "openstep", "OPENSTEP SoundKit output driver", OPENSTEPAUDIO_Init, SDL_FALSE
};

#endif
