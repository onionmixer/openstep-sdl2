/* Two numbers the audio investigation does not have yet.
 *
 * 1. What the conversion path costs on this machine.  Both games hand SDL a
 *    rate the device does not run at (water1 49716, quake 11025/22050), so
 *    every buffer goes through SDL's sinc resampler (5 zero crossings a
 *    side, float) plus S16 <-> F32 and a byteswap to S16MSB.  The backend's
 *    report shows thread CPU only inside long gaps, never the steady cost.
 *    This program feeds SILENCE from a callback that costs nothing, so the
 *    task's CPU time over the run IS the conversion path (plus the backend's
 *    own malloc+memcpy per buffer).  Run it at 44100 (no stream at all) and
 *    at the game rates; the difference is the resampler.
 *
 * 2. Who else is in this task and at what priority.  libsound forks a
 *    reply thread (perform_reply_thread) that sits in the completion chain
 *    between the kernel and SNDWait; nothing has ever looked at its
 *    priority.  task_threads() lists every thread; the boosted one is
 *    SDL's, the main one is this, and the rest belong to libsound.
 *
 *   cc -m486 -O -D__OPENSTEP__ -I/LocalDeveloper/Headers/SDL2 \
 *      sndcost.c /LocalDeveloper/Libraries/libSDL2.a \
 *      /ndrv2/openstep-matrox-remade/build/mesa/libGL.a -lm \
 *      -framework AppKit -framework Foundation -framework SoundKit \
 *      -o sndcost
 *
 *   (libGL.a because the installed libSDL2.a carries the GL backend and
 *   references OSMesa; glquake links the same file.)
 *
 *   ./sndcost <rate> [seconds]        e.g.  ./sndcost 44100 20
 *                                           ./sndcost 49716 20
 *                                           ./sndcost 11025 20
 */
#include <stdio.h>
#include <stdlib.h>
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_interface.h>
#include <mach/task_info.h>
#include <mach/thread_info.h>
#include "SDL.h"

static Uint32 callbacks = 0;

static void FillSilence(void *unused, Uint8 *stream, int len)
{
    (void)unused;
    SDL_memset(stream, 0, (size_t)len);
    ++callbacks;
}

/* Summed over the task's threads, not TASK_BASIC_INFO: on this kernel the
 * task's own user/system time stays at zero while its threads run (measured
 * 2026-09-09 -- 0.000 s after 22 s of audio), whereas THREAD_BASIC_INFO
 * counts.  Every thread is summed, so libsound's reply thread is in too. */
static double TaskCpuSeconds(void)
{
    thread_array_t list;
    unsigned int n, i;
    double total = 0.0;
    if (task_threads(task_self(), &list, &n) != KERN_SUCCESS)
        return -1.0;
    for (i = 0; i < n; i++) {
        struct thread_basic_info bi;
        unsigned int c1 = THREAD_BASIC_INFO_COUNT;
        if (thread_info(list[i], THREAD_BASIC_INFO, (thread_info_t)&bi, &c1) != KERN_SUCCESS) continue;
        total += (double)bi.user_time.seconds + bi.user_time.microseconds / 1e6
               + (double)bi.system_time.seconds + bi.system_time.microseconds / 1e6;
    }
    return total;
}

static void ListThreads(const char *when)
{
    thread_array_t list;
    unsigned int n, i;
    thread_t me = thread_self();

    if (task_threads(task_self(), &list, &n) != KERN_SUCCESS) {
        printf("%s: task_threads failed\n", when);
        return;
    }
    printf("%s: %u thread(s) in this task\n", when, n);
    for (i = 0; i < n; i++) {
        struct thread_basic_info bi;
        struct thread_sched_info si;
        unsigned int c1 = THREAD_BASIC_INFO_COUNT, c2 = THREAD_SCHED_INFO_COUNT;
        if (thread_info(list[i], THREAD_BASIC_INFO, (thread_info_t)&bi, &c1) != KERN_SUCCESS) continue;
        if (thread_info(list[i], THREAD_SCHED_INFO, (thread_info_t)&si, &c2) != KERN_SUCCESS) continue;
        printf("  thread %u%s: base %d cur %d max %d policy %d depressed %d"
               " cpu %ld.%03ld s state %d\n",
               i, list[i] == me ? " (main)" : "",
               (int)bi.base_priority, (int)bi.cur_priority, (int)si.max_priority,
               (int)si.policy, (int)si.depressed,
               (long)(bi.user_time.seconds + bi.system_time.seconds),
               (long)((bi.user_time.microseconds + bi.system_time.microseconds) / 1000 % 1000),
               (int)bi.run_state);
    }
}

int main(int argc, char **argv)
{
    SDL_AudioSpec want, have;
    SDL_AudioDeviceID dev;
    int rate, seconds = 20;
    double c0, c1;

    if (argc < 2) { fprintf(stderr, "usage: sndcost <rate> [seconds]\n"); return 2; }
    rate = atoi(argv[1]);
    if (argc > 2) seconds = atoi(argv[2]);
    if (seconds < 1) seconds = 1;

    if (SDL_Init(SDL_INIT_AUDIO) != 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    SDL_memset(&want, 0, sizeof(want));
    want.freq = rate;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = FillSilence;
    dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);   /* no changes allowed: the game's shape */
    if (dev == 0) { fprintf(stderr, "SDL_OpenAudioDevice: %s\n", SDL_GetError()); return 1; }
    printf("asked %d Hz, got %d Hz, %d ch, %d frames a callback; stream %s\n",
           rate, have.freq, (int)have.channels, (int)have.samples,
           (have.freq == 44100) ? "NOT needed (device rate)" : "in the path");

    c0 = TaskCpuSeconds();
    SDL_PauseAudioDevice(dev, 0);
    SDL_Delay(2000);                       /* let the thread settle and prime */
    ListThreads("while playing");
    SDL_Delay((Uint32)seconds * 1000U);
    c1 = TaskCpuSeconds();
    SDL_CloseAudioDevice(dev);             /* the backend prints its own report here */

    printf("all-thread cpu over %d s of silence at %d Hz: %.3f s = %.1f%% of one processor"
           " (%u callbacks)\n", seconds + 2, rate, c1 - c0,
           100.0 * (c1 - c0) / (double)(seconds + 2), (unsigned)callbacks);
    SDL_Quit();
    return 0;
}
