/* OPENSTEP SoundKit output backend for SDL2. The common SDL2 audio core owns
   the callback thread and converts input to this driver's S16MSB device
   format; this backend retains only queued SoundKit buffers. */
#include "../../SDL_internal.h"

#ifdef SDL_AUDIO_DRIVER_OPENSTEP

#import <SoundKit/SoundKit.h>
#import <sound/sound.h>

#include "SDL_audio.h"
#include "SDL_timer.h"
#include "../SDL_sysaudio.h"
#include "SDL_openstepaudio.h"
#include "../../thread/openstep/SDL_openstepmutex_c.h"

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
    if (_this->hidden->started && _this->hidden->count == 0) {
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
    if (!_this->hidden->primed) {
        _this->hidden->primed = 1;
        OPENSTEPAUDIO_Enqueue(_this, NULL, (Uint32)OPENSTEP_AUDIO_PRIMER_BYTES);
    }
    OPENSTEPAUDIO_Enqueue(_this, _this->hidden->mixbuf, _this->hidden->mixlen);
    if (!_this->hidden->hooked) {
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
    if (_this->hidden->count >= _this->hidden->ahead) {
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

static void OPENSTEPAUDIO_CloseDevice(_THIS)
{
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
