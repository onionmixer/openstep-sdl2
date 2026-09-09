# OPENSTEP SDL2 2.32.10 — openstep.4

Fourth OPENSTEP 4.2 Intel i486 release of upstream SDL 2.32.10.

**This release is about audio again, and about a crash that was never
reported as one.** openstep.3 claimed 250 ms of protection against a late
refill and actually had 85–90. This release has 220–280, at the same
latency, and it fixes a recursion in `SDL_Delay(0)` that could exhaust
the stack of any thread that lost a race for a spinlock.

## What changed

### `SDL_Delay(0)` no longer calls the timer

`SDL_Delay(0)` is what SDL's core spinlock falls back to when it cannot
take a lock. On this port it called `SDL_GetTicks64()`, which takes
`openstep_ticks_lock` — the very lock the caller may be spinning on — and
then returned without ever reaching `select()`, because the elapsed time
was already non-negative. Nothing yielded and nothing slept, so the
fallback called itself again: a few hundred frames deep in under a
millisecond, until the stack was gone.

It now calls `cthread_yield()`, which is `swtch_pri(0)`: the caller is
depressed and the processor goes to whoever is runnable, the lock holder
included. That is the one thing a spinlock fallback has to do.

This is not a subtle path. Any program that contends for an SDL spinlock
— the audio core does, on every buffer, with a conversion stream — was
exposed to it.

### The reserve was measured, and it was not what the comment said

The backend plays each SDL buffer as its own SoundKit sound and keeps
several queued so the device never runs dry. How much lateness that
actually survives had been reasoned about but never measured.

The kernel is why the reasoning was wrong. IOAudio mixes a few
descriptors ahead of the play point and, when it comes up short, **pads
with silence rather than stopping** — so the dropouts were inaudible to
every counter in the driver and in this backend. The relation is

    reserve = (AHEAD - 1) x buffer - C

with `C` a property of the kernel's lead and the notification chain, not
of the buffer size. Measured, `C` is 160–165 ms.

| | buffer | ahead | latency | real reserve |
|---|---|---|---|---|
| openstep.3 | `freq/8` (125 ms) | 3 | 375 ms | **85–90 ms** |
| openstep.4 | `freq/16` (62.5 ms) | 6 | 375 ms | **220–280 ms** |

glquake's frame is 165–176 ms, so under openstep.3 a single late frame
put silence on the output and no tuning of that geometry could have
changed it. Smaller buffers are strictly better at a fixed latency,
because the reserve is `latency - buffer - C`.

The first `PlayDevice` also sends one 8192-byte region of silence ahead
of the first real buffer, so the kernel fixes its mixing lead from the
smallest region it will ever see. That alone is worth 60 ms of reserve,
measured.

`test/openstep/sndslack.c` is the instrument and `docs/measurements/`
holds every run. The model predicted four outcomes at a second geometry
before they were measured, and all four came out as predicted.

### SDL mutexes block instead of spinning

`SDL_mutex` was a raw cthreads mutex. On this system `mutex_spin_limit`
is 0, so a waiter goes straight into `while (1) { ...; cthread_yield(); }`
— unbounded, and `cthread_yield()` is `swtch_pri(0)`, which lowers the
waiter's own priority on every turn. A thread that wanted the audio lock
could be pushed below the thread holding it.

It is now the pattern NeXT's own `NXLock` uses: a guard mutex and
`condition_wait`, which yields seven times and then blocks in
`msg_receive`. Measured in a game, 11,899 acquisitions cost 60 ms in
total with a worst case under a millisecond.

`SDL_OPENSTEP_MUTEX=yield` restores the old behaviour.

### `SDL_SYS_SetThreadPriority` is implemented

It was a stub returning `SDL_Unsupported()`, so the core's request for
`SDL_THREAD_PRIORITY_TIME_CRITICAL` on the audio thread did nothing. The
audio thread now runs at this machine's maximum of 18 against a main
thread at 10. `SDL_OPENSTEP_THREAD_PRIORITY=off` restores the stub.

openstep.3's notes said raising the priority would change nothing,
citing a measurement. That measurement was taken before the kernel's
silence padding was understood, and it was reading a counter that could
not see the fault.

### The sound buffers are allocated once

The backend used to `SDL_malloc` a fresh `SNDSoundStruct` for every
buffer and free it when `SNDWait` returned — sixteen allocations a second
of eleven kilobytes each. They are now a pool of eight, written once at
open so their pages are faulted in there and never again. Worst
`SDL_malloc` inside a submission fell from 854 us to 19.

`SDL_OPENSTEP_BUFFER_POOL=0` restores the old behaviour.

### The backend can be asked what it did

Nothing is printed uninvited. A normal run used to leave a line of ours
on the application's INFO channel on the way out; the only two things the
backend now says without being asked are a play SoundKit refused and a
queue that actually ran dry, and those go to `SDL_LOG_CATEGORY_AUDIO` at
error level, where a program that does not want them can silence them by
category.

Set `SDL_OPENSTEP_AUDIO_REPORT=1` and the backend prints, once, when the
device closes and never while it is playing: how many buffers it
submitted, a histogram of the interval between a wait returning and the
next submission, a histogram of the submissions themselves and of
`SNDWait`, every submission over 25 ms with its time, the queue depth and
which part of it was slow, and the buffer at which the application
stopped being paused. Underruns and failed plays are reported without
the switch, because those are faults rather than measurements.

Three more switches exist for measuring, and all three default to what
ships: `SDL_OPENSTEP_QUEUE_AHEAD`, `SDL_OPENSTEP_BUFFER_MS` and
`SDL_OPENSTEP_HELPER_PRIORITY`.

## Measured and rejected

On record so nobody repeats them blind. Every one of these was tried
against a real game and a bench harness on the machine.

| | result |
|---|---|
| `QUEUE_AHEAD` 6 → 5, to step off libsound's six-sound admission limit | the long stalls stayed; it only spends reserve |
| buffers of 83 or 100 ms, for more reserve | stalls just as often, and the added latency was audible |
| raising libsound's own background thread to the audio thread's priority | **much worse** — 986 ms inside one submission |
| a silence fast path when nothing is sounding | not bit-exact: a fully attenuated operator returns −1, and unkeyed rhythm phase feeds keyed voices |

## What is still wrong

About one submission in twenty takes 300–500 ms, always inside
libsound's `SNDStartPlaying`, always with no processor time. It was
reproduced on the bench: a thread doing **real, uncached** disk reads —
a raw device, or a file at random offsets — makes that call block in the
same process, whatever the audio thread's priority. A cached read does
not, drawing does not, a drained queue does not.

So it is heard when a game loads from the disk, and there is no repair
inside this backend: the submission is an out-of-line Mach message and it
goes through the paths the disk read is holding. Avoiding it means not
calling libsound per buffer at all, which is a different library.

`openstep-sdl20/ANAYLIZE_SDL2_SOUND_OPTIMIZATION.md` carries the whole
investigation, including what was believed and turned out to be false.

## Installer packages

- `OpenStepSDL2Libraries.pkg` — static `libSDL2.a`.
- `OpenStepSDL2Headers.pkg` — public headers, `SDL_openstepglpresent.h`, and
  documentation.
- `OpenStepSDL2Demos.pkg` — demo source, assets, rebuild scripts and i386
  binaries.

Extract the outer `.pkg.tar.gz` and open the contained `.pkg` with OPENSTEP
Installer. `SHA256SUMS` lists every archive.

**Applications built against openstep.3 must be relinked.** The library is
static, and everything above is inside it.

## Scope and limitations

As openstep.3. Playback only through SoundKit; no capture; software
surfaces in a window, OpenGL through the Matrox G450 driver's accelerated
Mesa when registered, stock Mesa otherwise.
