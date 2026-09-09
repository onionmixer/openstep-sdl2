/*
 * sndslack.c -- what does the kernel's audio pipeline actually give us?
 *
 * ANAYLIZE_SDL2_SOUND_OPTIMIZATION.md says every recommendation in it rests
 * on one piece of arithmetic taken out of a disassembly:
 *
 *      real slack = (AHEAD-1) * buffer  -  L * descriptor   ( - a phase term)
 *
 * where the kernel's mixer is L descriptors AHEAD of the play point and pads
 * a short descriptor with silence rather than stopping.  The SDL backend's
 * own comment assumes the slack is (AHEAD-1)*buffer, with no L in it -- 250 ms
 * where the model says 64..111.  Nothing about that has ever been measured.
 * This program measures it, from userland, with SoundKit alone: no SDL, no
 * window, no disk, no driver.
 *
 * IT IMITATES THE SDL BACKEND, deliberately and exactly (compare
 * port/openstep/src/audio/openstep/SDL_openstepaudio.m:91-126): one
 * SNDSoundStruct malloc'd per buffer, the samples memcpy'd in, played with
 * SNDStartPlaying(s, tag, 0, 0, ...) so it queues first-come-first-served,
 * and the oldest tag reclaimed with SNDWait once AHEAD of them are out.
 * Samples are BIG-endian 16-bit stereo because that is what the backend
 * hands over (AUDIO_S16MSB).  If this program and that backend disagree
 * about anything, this program is measuring a different system.
 *
 * FOUR QUESTIONS, CHEAPEST FIRST.  Each one can refute the model on its own.
 *
 *   mode 0  IS A COMPLETION A PLAYBACK EVENT?
 *           Play one sound of L ms and time SNDStartPlaying -> SNDWait.
 *           Repeated for 250/500/1000/2000 ms.  If the time tracks the
 *           length, completion is paced by playback; if it is ~0, completion
 *           is at copy time and the whole model's arithmetic changes.
 *           (This cannot prove the completion is the DAC's -- only that it
 *           is not the copy.)
 *
 *   mode 1  IS COMPLETION QUANTISED TO A DESCRIPTOR, AND HOW BIG IS IT?
 *           Run the loop with no stalls and print every SNDWait return time.
 *           If completions land on a descriptor grid, the residual
 *           t[k] - k*T is a SAWTOOTH whose amplitude is the descriptor and
 *           whose period is set by T/d.  With T = 5512 frames the model
 *           predicts a 4..43 ms sawtooth repeating every 256 sounds; with
 *           T = 4096 frames -- exactly two descriptors -- it predicts a flat
 *           line.  A flat line at 5512 refutes the descriptor model outright,
 *           and the sawtooth's amplitude measures d without assuming 8192
 *           bytes or the sample rate.  Nothing starves; nothing restarts.
 *
 *   mode 2  HOW LATE MAY ONE BUFFER BE?
 *           The same loop, but every SPACING iterations one submission is
 *           held back by STALL ms.  A stall that starved the device shows as
 *           a permanent step in the residual, because the inserted silence
 *           pushes every later completion out; a stall that fitted inside the
 *           slack leaves no trace.  The decisive pair is 160 ms at AHEAD 3
 *           against AHEAD 4: the model says always starves / never starves,
 *           and the backend's own assumption says never / never.
 *
 *   mode 3  DOES THE FIRST BUFFER'S SIZE SET THE LEAD?
 *           The model says the kernel mixes as many descriptors at DMA start
 *           as the first region fills, and then holds that number.  So a
 *           first buffer of exactly two descriptors should buy a whole
 *           descriptor of extra slack -- which is candidate fix A1, tested
 *           here before a line of SDL is touched.  Each trial re-primes from
 *           a drained device, because a restart re-picks the lead.
 *
 * WHAT IT DOES NOT DO.  It cannot count the padded descriptors themselves
 * (that needs the backend's own begin/end callbacks), and it says nothing
 * about contention with video.  It also cannot hear: "silence was inserted"
 * is inferred from the completion timeline, so a run worth trusting should
 * be listened to at least once.
 *
 * Times are printed raw, in microseconds, and analysed off the machine --
 * printf during playback would perturb what is being measured, which has
 * already happened twice in this investigation.
 *
 * Build:  cc -O -o sndslack sndslack.c -framework SoundKit
 * Run:    sndslack 0
 *         sndslack 1 <frames> <seconds>
 *         sndslack 2 <frames> <ahead> <stall_ms> <spacing> <seconds> [first_frames]
 *         sndslack 3 <frames> <first_frames> <stall_ms> <trials>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>
#ifdef __NeXT__
#include <libc.h>          /* select(2); OPENSTEP keeps it in bsd/libc.h,
                            * which is where SDL's own timer backend gets it */
#else
#include <sys/select.h>    /* the host syntax check only */
#endif
#include <sound/sound.h>
#include <sys/types.h>
#include <sys/dir.h>       /* opendir/readdir: BSD spelling, struct direct */

#define RATE            44100
#define CHANNELS        2
#define MAXFRAMES       88200      /* two seconds: mode 0's longest sound */
#define MAXSLOTS        16
#define MAXEVENTS       6000

/* The samples every buffer carries.  Made once and memcpy'd, as the backend
 * does: generating them inside the loop would charge this program's own
 * arithmetic to the audio thread's deadline. */
static short           tone[MAXFRAMES * CHANNELS];

/* The queue, shaped like the backend's. */
static SNDSoundStruct *sounds[MAXSLOTS];
/*
 * SNDSLACK_POOL: hand libsound the SAME eight buffers over and over
 * instead of a fresh malloc every time.
 *
 * The backend's own numbers ruled the buffer pool out as a CPU saving --
 * malloc's worst was 854 us against 508,008 us inside SNDStartPlaying.
 * That is not the same question as whether it helps HERE.  The stalls are
 * inside the driver call, they only appear under real (uncached) disk
 * reads, and a plausible reason for that shape is the kernel having to
 * make the region ready for DMA while the paging path is busy.  If that
 * is it, a buffer the driver has already seen may cost less than a fresh
 * one -- and if it makes no difference, the pool is dead for good rather
 * than dead on a CPU argument that never addressed this.
 *
 * Safe because SNDWait has returned for a slot before it is reused, which
 * is the same guarantee the backend's own slots rely on.
 */
static SNDSoundStruct *pool[MAXSLOTS];
static int             use_pool;
static int             tags[MAXSLOTS];
static int             head, count, next_tag;

/*
 * MODE 4: WHAT SNDStartPlaying COSTS, AND WHAT MAKES IT COST THAT.
 *
 * The SDL backend's own instrumentation says every slow submission is
 * inside SNDStartPlaying -- 197 of 1351 over 25 ms in one game, with the
 * processor time inside them at zero, so it is a block and not work.  It
 * also says backing the queue off libsound's six-sound admission limit
 * (QUEUE_AHEAD 6 -> 5) does not stop the big ones.  Going further needs
 * experiments, and experiments should not cost somebody a game each.
 *
 * So: time every SNDStartPlaying, bucket it, keep the slow ones with a
 * timestamp -- and optionally run a thread that keeps the disk busy,
 * because that is when the listener hears it.
 */
static double now_us(void);            /* defined below; record_start needs it */
/*
 * Run the submit loop on a FORKED thread rather than on main.
 *
 * The last difference left between this program and the game.  SDL runs
 * its audio loop on a thread it makes with cthread_fork and then raises
 * to 18; sndslack has been submitting from main all along.  libsound's
 * queue lock, its condition variables and its own reply thread are all
 * cthreads machinery, and "which thread called" is exactly the kind of
 * thing that can matter to it.  Everything else -- disk load, a drained
 * queue, priority, drawing through the window server -- has been tried
 * and none of it reproduced the game's 14.6%.
 */
static int  th_frames, th_ahead, th_secs;

static any_t submit_thread(any_t arg)
{
    (void)arg;
    loop(th_frames, th_ahead, 0, 0, th_secs, 0);
    return (any_t)0;
}

static void dump_starts(const char *what);

/* Submit silence rather than a tone.  Set by mode 4 and by
 * SNDSLACK_SILENT; a plain flag because this libc has no putenv(). */
static int silent_buffers;

static unsigned long start_hist[8];
static int    nslow;
static double slow_at[64];
static double slow_us[64];
static double t_zero;

static void record_start(double us)
{
    int b;
    if      (us <    500.0) b = 0;
    else if (us <   1000.0) b = 1;
    else if (us <   2000.0) b = 2;
    else if (us <   5000.0) b = 3;
    else if (us <  25000.0) b = 4;
    else if (us < 100000.0) b = 5;
    else if (us < 250000.0) b = 6;
    else                    b = 7;
    ++start_hist[b];
    if (us >= 25000.0) {
        if (nslow < 64) {
            slow_at[nslow] = (now_us() - t_zero) / 1000.0;
            slow_us[nslow] = us;
        }
        ++nslow;
    }
}

/* Recorded events: when each SNDWait returned, and whether a stall was
 * taken before the submission that followed it. */
static double          ev_us[MAXEVENTS];
static int             ev_stall[MAXEVENTS];
static int             nev;

static double now_us(void)
{
    struct timeval t;

    gettimeofday(&t, (struct timezone *)0);
    return (double)t.tv_sec * 1000000.0 + (double)t.tv_usec;
}

/* SDL_Delay's own method.  usleep is not used anywhere in this program:
 * on a cthread it blocks for ever, and that trap has been paid for once
 * already in this workspace. */
static void delay_ms(int ms)
{
    struct timeval tv;

    if (ms <= 0) return;
    tv.tv_sec  = ms / 1000;
    tv.tv_usec = (ms % 1000) * 1000;
    select(0, 0, 0, 0, &tv);
}

static void make_tone(int frames)
{
    int i;
    double step = 2.0 * 3.14159265358979 * 440.0 / (double)RATE;
    double phase = 0.0;

    /* SNDSLACK_SILENT: submit silence instead of a tone.  libsound and the
     * kernel do exactly the same work either way, and the machine this
     * runs on has somebody sitting at it -- a 440 Hz tone for minutes on
     * end is not a measurement, it is a nuisance.  Mode 4 sets it. */
    {
        const char *q = getenv("SNDSLACK_SILENT");
        if (silent_buffers || (q != 0 && atoi(q) != 0)) {
            memset((char *)tone, 0, (size_t)frames * CHANNELS * sizeof(short));
            return;
        }
    }

    for (i = 0; i < frames; i++) {
        short v = (short)(6000.0 * sin(phase));
        /* BIG-endian, because that is what the SDL backend hands SoundKit.
         * Written by hand rather than by a byte swap so it is obvious. */
        unsigned short u = (unsigned short)v;
        unsigned char *p = (unsigned char *)&tone[i * CHANNELS];
        p[0] = (unsigned char)(u >> 8);
        p[1] = (unsigned char)(u & 0xff);
        p[2] = p[0];
        p[3] = p[1];
        phase += step;
        if (phase > 2.0 * 3.14159265358979) phase -= 2.0 * 3.14159265358979;
    }
}

/*
 * TWO KNOBS FOR THE COMPLETION CHAIN (2026-09-09), both from the environment
 * so every mode keeps its arguments:
 *
 *   SNDSLACK_LOAD=1     after the first submission, fork one thread that
 *                       spins forever at the default priority.  That is a
 *                       game's main thread as the scheduler sees it, and
 *                       without it this program never contends for anything.
 *   SNDSLACK_BOOST=N    raise THIS thread to N (the SDL backend runs its
 *                       audio thread at 18 here), and, unless
 *                       SNDSLACK_BOOST_SELF_ONLY=1, also every other thread
 *                       already in the task -- which, taken right after the
 *                       first submission and before the load thread exists,
 *                       is exactly libsound's reply thread.  sndcost measured
 *                       that thread at base 10: the same priority as the
 *                       load, in the middle of the chain that wakes SNDWait.
 *
 * Arms: LOAD alone with BOOST_SELF_ONLY is today's SDL (audio 18, libsound
 * 10); LOAD with BOOST is candidate 3 (both 18); neither is the baseline.
 * If the reserve measured by mode 2 drops under LOAD and recovers with BOOST,
 * the reply thread's priority is part of C.
 */
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_interface.h>
#include <mach/thread_info.h>
#include <mach/cthreads.h>

static int chain_hooked = 0;

static any_t load_thread(any_t arg)
{
    volatile unsigned spin = 0;
    (void)arg;
    for (;;) ++spin;
    return 0;
}

static void hook_chain_once(void)
{
    const char *b = getenv("SNDSLACK_BOOST");
    const char *l = getenv("SNDSLACK_LOAD");
    const char *o = getenv("SNDSLACK_BOOST_SELF_ONLY");
    int pri = b ? atoi(b) : 0;

    if (chain_hooked) return;
    chain_hooked = 1;
    if (pri > 0) {
        thread_array_t list;
        unsigned int n, i;
        thread_t me = thread_self();
        kern_return_t kr = thread_priority(me, pri, FALSE);
        fprintf(stderr, "sndslack: self -> %d: kr %d\n", pri, (int)kr);
        if (!(o && atoi(o)) && task_threads(task_self(), &list, &n) == KERN_SUCCESS) {
            for (i = 0; i < n; i++) {
                if (list[i] == me) continue;
                kr = thread_priority(list[i], pri, FALSE);
                fprintf(stderr, "sndslack: thread %u -> %d: kr %d\n", i, pri, (int)kr);
            }
        }
    }
    if (l && atoi(l)) {
        cthread_detach(cthread_fork(load_thread, (any_t)0));
        fprintf(stderr, "sndslack: load thread started\n");
    }
}

/* One buffer, submitted the way the backend submits one.  Returns the tag,
 * or 0 if SoundKit refused it. */
static int submit(int frames)
{
    SNDSoundStruct *s;
    int bytes = frames * CHANNELS * (int)sizeof(short);
    int slot, err;

    slot = (head + count) % MAXSLOTS;
    if (use_pool) {
        if (pool[slot] == 0) {
            pool[slot] = (SNDSoundStruct *)malloc(sizeof(*s)
                          + MAXFRAMES * CHANNELS * (int)sizeof(short));
        }
        s = pool[slot];
    } else {
        s = (SNDSoundStruct *)malloc(sizeof(*s) + bytes);
    }
    if (s == 0) return 0;
    s->magic        = SND_MAGIC;
    s->dataLocation = sizeof(*s);
    s->dataSize     = bytes;
    s->dataFormat   = SND_FORMAT_LINEAR_16;
    s->samplingRate = RATE;
    s->channelCount = CHANNELS;
    memcpy(((char *)s) + sizeof(*s), (char *)tone, bytes);

    ++next_tag;
    if (next_tag <= 0) next_tag = 1;
    {
        double t0 = now_us();
        err = SNDStartPlaying(s, next_tag, 0, 0, SND_NULL_FUN, SND_NULL_FUN);
        record_start(now_us() - t0);
    }
    if (err != SND_ERR_NONE) {
        if (!use_pool) free(s);
        fprintf(stderr, "sndslack: SNDStartPlaying returned %d\n", err);
        return 0;
    }
    sounds[slot] = s;
    tags[slot]   = next_tag;
    ++count;
    return next_tag;
}

/* Reclaim the oldest, as WaitDevice does.  Returns the wall time at which
 * SNDWait returned -- that is a playback-paced event and the whole
 * measurement hangs on it. */
static double reclaim(void)
{
    int slot = head;
    double t;
    int err;

    if (count <= 0) return now_us();
    err = SNDWait(tags[slot]);
    t = now_us();
    if (err != SND_ERR_NONE)
        fprintf(stderr, "sndslack: SNDWait returned %d\n", err);
    if (!use_pool) free(sounds[slot]);
    sounds[slot] = 0;
    head = (slot + 1) % MAXSLOTS;
    --count;
    return t;
}

static void drain(void)
{
    while (count > 0)
        (void)reclaim();
}

static void mode0(void)
{
    static const int lengths[4] = { 250, 500, 1000, 2000 };
    int i;

    printf("mode 0: one sound at a time; Start -> Wait, against its length\n");
    printf("  length_ms  waited_ms  ratio\n");
    for (i = 0; i < 4; i++) {
        int frames = RATE * lengths[i] / 1000;
        double t0, t1;

        if (frames > MAXFRAMES) {
            /* MAXFRAMES caps the shared tone buffer; longer sounds repeat it
             * by submitting several, which would not be one sound.  Say so
             * rather than silently measuring something else. */
            printf("  %9d  (skipped: over the %d-frame tone buffer)\n",
                   lengths[i], MAXFRAMES);
            continue;
        }
        make_tone(frames);
        t0 = now_us();
        if (submit(frames) == 0) continue;
        (void)reclaim();
        t1 = now_us();
        printf("  %9d  %9.1f  %.3f\n", lengths[i], (t1 - t0) / 1000.0,
               (t1 - t0) / 1000.0 / (double)lengths[i]);
        fflush(stdout);
        /* Let the device settle between sounds so each is a cold start of
         * its own rather than a continuation of the last. */
        delay_ms(300);
    }
}

/* The loop both mode 1 and mode 2 run: submit, and once AHEAD are out,
 * reclaim the oldest and (sometimes) be late with the next one. */
static void loop(int frames, int ahead, int stall_ms, int spacing, int secs,
                 int first_frames)
{
    double t_end;
    int iter = 0;
    int stall_next = 0;

    make_tone(frames);
    t_end = now_us() + (double)secs * 1000000.0;
    nev = 0;

    if (first_frames > 0 && first_frames != frames) {
        /* The first region decides the kernel's lead, if the model is right.
         * It carries the same tone, just less of it. */
        if (submit(first_frames) == 0) return;
        hook_chain_once();
    }
    while (now_us() < t_end && nev < MAXEVENTS) {
        if (stall_next) {
            delay_ms(stall_ms);
            stall_next = 0;
            ev_stall[nev > 0 ? nev - 1 : 0] = stall_ms;
        }
        if (submit(frames) == 0) break;
        hook_chain_once();
        if (count >= ahead) {
            ev_us[nev] = reclaim();
            ev_stall[nev] = 0;
            ++nev;
            ++iter;
            if (spacing > 0 && stall_ms > 0 && (iter % spacing) == 0)
                stall_next = 1;
        }
    }
    drain();
}

static void dump(int frames, int ahead, const char *what)
{
    int i;

    printf("# %s\n", what);
    printf("# frames %d  ahead %d  rate %d  channels %d  events %d\n",
           frames, ahead, RATE, CHANNELS, nev);
    printf("# k  wait_return_us  stall_ms_taken_after\n");
    for (i = 0; i < nev; i++)
        printf("%d %.0f %d\n", i, ev_us[i] - ev_us[0], ev_stall[i]);
}

/*
 * A thread that keeps the disk busy, because that is the condition the
 * listener describes: "when the disk loads", "when the ending screen is
 * read".  It walks a directory and reads every ordinary file in it, over
 * and over, at ordinary priority -- the same thing the game's own loading
 * does, on a thread that is not the audio thread.
 */
static char disk_dir[256];
static char raw_path[256];

/*
 * READ-ONLY, AND IT HAS TO BYPASS THE BUFFER CACHE.
 *
 * The first version of this walked a directory over and over, which after
 * the first pass is served entirely out of the buffer cache: it made the
 * machine copy memory, not turn a disk.  That is not the condition the
 * listener describes -- "when it loads from the disk".  A raw device
 * (/dev/rhd0a and friends) is not cached, so a sequential read of one is
 * real head movement and real controller traffic, for as long as it runs.
 *
 * It only ever reads.  Nothing here opens anything for writing.
 */
static any_t raw_thread(any_t arg)
{
    static char buf[65536];
    int fd;
    (void)arg;
    for (;;) {
        fd = open(raw_path, 0);         /* O_RDONLY */
        if (fd < 0) { delay_ms(1000); continue; }
        for (;;) {
            int n = read(fd, buf, sizeof(buf));
            if (n <= 0) break;
        }
        close(fd);
    }
    return (any_t)0;
}

/*
 * Read a FILE, through the filesystem, at random offsets.
 *
 * The raw-device thread turns the disk but skips the filesystem: no
 * inode lookups, no page-ins, no uiomove into a user buffer.  The game
 * does all three when it loads a song or a screen, and its stalls are
 * 300-500 ms where the raw load's were 26-185.  If the difference is the
 * filesystem path rather than the disk, this thread will show it.
 *
 * Random offsets on purpose: sequential reads are served by read-ahead
 * after the first block, and a file read twice comes out of the buffer
 * cache.  Read-only, like everything else here.
 */
static char file_path[256];

static any_t file_thread(any_t arg)
{
    static char buf[65536];
    unsigned long seed = 12345;
    int fd;
    (void)arg;
    for (;;) {
        fd = open(file_path, 0);
        if (fd < 0) { delay_ms(1000); continue; }
        {
            long size = lseek(fd, 0L, 2);   /* SEEK_END */
            int i;
            if (size < 65536L) size = 65536L;
            for (i = 0; i < 64; i++) {
                long off;
                seed = seed * 1103515245UL + 12345UL;
                off = (long)((seed >> 8) % (unsigned long)size);
                lseek(fd, off, 0);
                if (read(fd, buf, sizeof(buf)) <= 0) break;
            }
        }
        close(fd);
    }
    return (any_t)0;
}

static any_t disk_thread(any_t arg)
{
    static char buf[32768];
    (void)arg;
    for (;;) {
        DIR *d = opendir(disk_dir);
        struct direct *e;
        if (d == 0) { delay_ms(500); continue; }
        while ((e = readdir(d)) != 0) {
            char path[512];
            int fd, n;
            if (e->d_name[0] == '.') continue;
            sprintf(path, "%s/%s", disk_dir, e->d_name);
            fd = open(path, 0);
            if (fd < 0) continue;
            while ((n = read(fd, buf, sizeof(buf))) > 0) { /* nothing */ }
            close(fd);
        }
        closedir(d);
    }
    return (any_t)0;
}

static void dump_starts(const char *what)
{
    static const char *edge[8] = { "<0.5", "  <1", "  <2", "  <5",
                                   " <25", "<100", "<250", ">=250" };
    int i;
    unsigned long n = 0;

    for (i = 0; i < 8; i++) n += start_hist[i];
    printf("# %s\n", what);
    printf("# SNDStartPlaying ms:");
    for (i = 0; i < 8; i++) printf(" %s:%lu", edge[i], start_hist[i]);
    printf("\n# %lu call(s), %d over 25 ms (%.1f%%)\n",
           n, nslow, n ? 100.0 * (double)nslow / (double)n : 0.0);
    for (i = 0; i < nslow && i < 64; i++)
        printf("# slow at %8.3f s: %.1f ms\n", slow_at[i] / 1000.0,
               slow_us[i] / 1000.0);
}

int main(int argc, char **argv)
{
    int mode = (argc > 1) ? atoi(argv[1]) : 0;

    head = 0; count = 0; next_tag = 0; nev = 0;

    if (mode == 0) {
        mode0();
        return 0;
    }
    if (mode == 1) {
        int frames = (argc > 2) ? atoi(argv[2]) : 5512;
        int secs   = (argc > 3) ? atoi(argv[3]) : 60;

        if (frames < 64 || frames > MAXFRAMES) {
            fprintf(stderr, "sndslack: frames out of range\n");
            return 2;
        }
        loop(frames, 3, 0, 0, secs, 0);
        dump(frames, 3, "mode 1: completion timeline, no stalls");
        return 0;
    }
    if (mode == 2) {
        int frames  = (argc > 2) ? atoi(argv[2]) : 5512;
        int ahead   = (argc > 3) ? atoi(argv[3]) : 3;
        int stall   = (argc > 4) ? atoi(argv[4]) : 160;
        int spacing = (argc > 5) ? atoi(argv[5]) : 41;
        int secs    = (argc > 6) ? atoi(argv[6]) : 120;
        /* The first region, if given, is what candidate fix A1 changes: the
         * model says the kernel takes its descriptor lead from whatever is
         * queued when DMA starts, and then holds it.  0 means "same as the
         * rest", which is what the SDL backend does today. */
        int first   = (argc > 7) ? atoi(argv[7]) : 0;

        if (frames < 64 || frames > MAXFRAMES || ahead < 2 || ahead >= MAXSLOTS ||
            first < 0 || first > MAXFRAMES) {
            fprintf(stderr, "sndslack: frames, ahead or first out of range\n");
            return 2;
        }
        t_zero = now_us();
        silent_buffers = 1;
        {
            const char *pl = getenv("SNDSLACK_POOL");
            use_pool = (pl != 0 && atoi(pl) != 0);
        }
        loop(frames, ahead, stall, spacing, secs, first);
        dump(frames, ahead, "mode 2: isolated stalls");
        printf("# stall_ms %d  spacing %d  first_frames %d\n", stall, spacing, first);
        /* The submission cost alongside the stalls: if a stall long enough
         * to drain the queue makes the NEXT SNDStartPlaying expensive, that
         * is the seam -- libsound releases the device when nothing is left
         * playing and the next start has to bring it back. */
        dump_starts("submission cost under injected stalls");
        return 0;
    }
    if (mode == 3) {
        int frames = (argc > 2) ? atoi(argv[2]) : 5512;
        int first  = (argc > 3) ? atoi(argv[3]) : 4096;
        int stall  = (argc > 4) ? atoi(argv[4]) : 120;
        int trials = (argc > 5) ? atoi(argv[5]) : 8;
        int t;

        if (frames < 64 || frames > MAXFRAMES || first < 64 || first > MAXFRAMES) {
            fprintf(stderr, "sndslack: frames out of range\n");
            return 2;
        }
        printf("# mode 3: first region %d frames, then %d; stall %d ms\n",
               first, frames, stall);
        for (t = 0; t < trials; t++) {
            /* Each trial starts from a drained device on purpose: a restart
             * re-picks the lead from whatever region is first, so a trial
             * that followed a starved one would be measuring the wrong
             * first region. */
            loop(frames, 3, stall, 12, 6, first);
            printf("# trial %d\n", t);
            dump(frames, 3, "mode 3 trial");
            fflush(stdout);
            delay_ms(500);
        }
        return 0;
    }
    if (mode == 4) {
        /* The SDL backend's own geometry: 44100/16 frames a buffer, the
           queue depth given, no artificial stalls at all.  Everything
           this mode reports is something the machine did by itself. */
        int frames = (argc > 2) ? atoi(argv[2]) : 2756;
        int ahead  = (argc > 3) ? atoi(argv[3]) : 6;
        int secs   = (argc > 4) ? atoi(argv[4]) : 60;
        const char *dd = getenv("SNDSLACK_DISK");

        if (frames < 64 || frames > MAXFRAMES || ahead < 2 || ahead >= MAXSLOTS) {
            fprintf(stderr, "sndslack: frames or ahead out of range\n");
            return 2;
        }
        t_zero = now_us();
        silent_buffers = 1;
        if (dd != 0 && dd[0] != 0) {
            strncpy(disk_dir, dd, sizeof(disk_dir) - 1);
            cthread_detach(cthread_fork((cthread_fn_t)disk_thread, (any_t)0));
            fprintf(stderr, "sndslack: cached-tree load on %s\n", disk_dir);
            delay_ms(500);
        }
        {
            const char *fp = getenv("SNDSLACK_FILE");
            if (fp != 0 && fp[0] != 0) {
                strncpy(file_path, fp, sizeof(file_path) - 1);
                cthread_detach(cthread_fork((cthread_fn_t)file_thread, (any_t)0));
                fprintf(stderr, "sndslack: FILE read load on %s\n", file_path);
                delay_ms(500);
            }
        }
        {
            const char *rp = getenv("SNDSLACK_RAW");
            if (rp != 0 && rp[0] != 0) {
                strncpy(raw_path, rp, sizeof(raw_path) - 1);
                cthread_detach(cthread_fork((cthread_fn_t)raw_thread, (any_t)0));
                fprintf(stderr, "sndslack: RAW read load on %s\n", raw_path);
                delay_ms(500);
            }
        }
        {
            const char *th = getenv("SNDSLACK_THREAD");
            if (th != 0 && atoi(th) != 0) {
                cthread_t t;
                th_frames = frames; th_ahead = ahead; th_secs = secs;
                t = cthread_fork((cthread_fn_t)submit_thread, (any_t)0);
                cthread_join(t);
                printf("# submitted from a forked thread\n");
            } else {
                loop(frames, ahead, 0, 0, secs, 0);
            }
        }
        /* Say BOTH loads in the line, not just one.  The first version of
           this reported only SNDSLACK_DISK, so a run driven by
           SNDSLACK_RAW printed "disk off" and the log lied about its own
           conditions. */
        printf("# mode 4: frames %d ahead %d secs %d tree %s raw %s\n",
               frames, ahead, secs,
               (dd && dd[0]) ? dd : "off",
               raw_path[0] ? raw_path : "off");
        dump_starts("submission cost");
        return 0;
    }
    fprintf(stderr, "usage: %s <0|1|2|3|4> ...\n", argv[0]);
    return 2;
}
