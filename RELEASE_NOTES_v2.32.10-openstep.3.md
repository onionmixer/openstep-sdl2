# OPENSTEP SDL2 2.32.10 — openstep.3

Third OPENSTEP 4.2 Intel i486 release of upstream SDL 2.32.10.

**This release is about audio latency.** openstep.2 kept a full second
of sound in flight; this one keeps three eighths of it, and the
difference is audible in anything interactive. The library and headers
are otherwise the same code, with one header made safe to include after
a program's own `<stdint.h>`.

## What changed

### The SoundKit backend queues less

The backend plays each SDL buffer as its own SoundKit sound and keeps a
few queued ahead so the device never runs dry. openstep.2 used a
quarter-second buffer with four queued, and so anything it played --
weapon fire in a game -- arrived a second after it was asked for.

| | buffer | queued ahead | latency | worst-phase reserve |
|---|---|---|---|---|
| openstep.2 | `freq/4` (250 ms) | 4 | 1000 ms | 750 ms |
| openstep.3 | `freq/8` (125 ms) | 3 | 375 ms | 250 ms |

The reserve is what protects playback while the application holds the
audio lock or the main thread hogs the processor for a frame: the first
queued buffer is already playing, so the guarantee is `AHEAD - 1`
buffers, not `AHEAD`. 250 ms was measured to be enough (below).

Underruns and failed plays are now counted and reported once at close.
A short gap that repeats is hard to judge by ear; a count is not.

### Measured, and left alone: `freq/16`

The obvious next step -- halve the buffer again -- was tried, so the
result is on record and nobody has to try it blind:

| buffer, 3 ahead | latency | reserve | result under CPU + disk load |
|---|---|---|---|
| `freq/8` | 375 ms | 250 ms | clean (0.11 % of the device's time dry) |
| `freq/16` | 187 ms | 125 ms | breaks up (3.7 % dry with an *idle* main thread; audible in Quake) |

The reserve and the latency are the same buffers, so the smallest
latency that keeps the proven reserve is `freq/16` with five queued, at
312 ms -- a 17 % gain that was not judged worth a change on the day it
was measured. The backend stays at `freq/8`. The measurements and the
reasoning are in `docs/PLAN_AUDIO_BUFFER_FREQ16.md`.

### `SDL_config_openstep.h` guards its `uintN_t` typedefs

The port's config header defines `uint8_t` .. `uint64_t`, `intptr_t` and
`uintptr_t` because OPENSTEP's own headers do not. It now wraps each in
the `_UINTn_T_DECLARED` / `_INTPTR_T_DECLARED` / `_UINTPTR_T_DECLARED`
guards that upstream SDL uses for the same purpose. C89 does not allow a
typedef name to be defined twice, and cc 2.7.2.1 rejects the translation
unit -- so an application that supplies these aliases itself could not
include SDL at all. With no guard predefined the preprocessed result is
byte-identical to openstep.2, so nothing that builds today changes.

### Smaller

- Two probes under `test/openstep/`: `openstep-thread-priority-probe.c`
  (what `thread_priority()` accepts on this kernel, and the
  `gettimeofday` step, which is 5 us) and
  `openstep-thread-priority-direction.c` (which end of Mach's 0..31 range
  is the high one -- the larger number, measured both ways). This port's
  `SDL_SYS_SetThreadPriority` remains a stub: the measurements showed the
  audio thread was not losing the processor, so raising its priority
  would have changed nothing. `docs/PLAN_THREAD_PRIORITY.md` has the plan
  that was not carried out, and why.
- The build tree on the target moved from `/tmp/SDL20` to `/me/SDL20`,
  so a reboot no longer discards it.
- The Mesa project is referred to by its correct name, `openstep-mesa342`.

## Installer packages

- `OpenStepSDL2Libraries.pkg` -- static `libSDL2.a`.
- `OpenStepSDL2Headers.pkg` -- public headers, `SDL_openstepglpresent.h`, and
  documentation.
- `OpenStepSDL2Demos.pkg` -- demo source, assets, rebuild scripts and i386
  binaries.

Extract the outer `.pkg.tar.gz` and open the contained `.pkg` with OPENSTEP
Installer. `SHA256SUMS` lists every archive.

Applications built against openstep.2 must be relinked to get the new
audio behaviour: the library is static.

## Scope and limitations

As openstep.2. Playback only through SoundKit; no capture; software
surfaces in a window, OpenGL through the Matrox G450 driver's accelerated
Mesa when registered, stock Mesa otherwise.
