# sndslack — what the audio pipeline actually gives us, measured

2026-09-09, on the OPENSTEP 4.2 machine (i386, EMU10K1 sound driver).
Raw data in this directory; the program is `../../test/openstep/sndslack.c`;
the reasoning is `../../ANAYLIZE_SDL2_SOUND_OPTIMIZATION.md`.

Every number here was produced by `sndslack`, a SoundKit-only program that
imitates the SDL backend's submission loop exactly (same SNDSoundStruct
fields, same `SNDStartPlaying(s, tag, 0, 0, ...)`, same "reclaim the oldest
with SNDWait once AHEAD are out"), with no SDL, no window and no disk.  The
analysis is done off the machine, in python, from these dumps.

## Why this was measured at all

The backend says, in `SDL_openstepaudio.h:11`, that the worst-phase reserve
is `(AHEAD - 1)` buffers -- 250 ms at the shipped setting.  Reading the
kernel's IOAudio out of `mach_kernel` suggested that could not be true: the
mixer runs some descriptors AHEAD of the play point and pads a short
descriptor with silence rather than stopping, so the reserve has a subtraction
in it that the comment does not.  Whether that subtraction is real, and how
big it is, decides whether any of the proposed fixes are worth building.

## How a starved device is detected

Not by ear, and not by wall-clock excess.  Completions land on a descriptor
grid, so the interval between two of them is an integer number of descriptors.
Counting `sum(round(interval / d))` and comparing it with the audio actually
submitted gives the inserted silence **in integer descriptors**, which is
immune to clock drift and to the stall's own duration.  A run with no stalls
gives 0.8 descriptors of excess over 479 intervals -- that is the noise floor.

## 1. Completion is a playback event, not a copy (`mode 0`)

| sound length | Start -> Wait | ratio |
|---|---|---|
| 250 ms | 291.5 ms | 1.166 |
| 500 ms | 513.2 ms | 1.026 |
| 1000 ms | 1025.4 ms | 1.025 |
| 2000 ms | 2049.8 ms | 1.025 |

The wait tracks the length.  Had `SNDWait` returned when the data was copied,
these would all be near zero, and the whole model would have been arithmetic
about nothing.  (The excess is consistent with descriptor quantisation plus
the notification chain; four points do not pin the descriptor down, which is
what the next section is for.)

## 2. The descriptor is 8192 bytes -- 46.44 ms (`mode 1`, `mode1-5512.txt`)

60 seconds, no stalls, 480 completions.  The intervals take exactly two
values:

| | measured | model | count | model |
|---|---|---|---|---|
| 2 descriptors | 92.7 ms | 92.88 | 30.7 % | 30.9 % |
| 3 descriptors | 139.4 ms | 139.32 | 69.3 % | 69.1 % |

The mix of twos and threes is forced by `T/d = 5512*4/8192 = 2.6914`: the
long-run fraction of threes must be 0.6914.  Over 479 intervals it came out
0.693 -- **0.17 percentage points**.  A 4096-byte descriptor would have
demanded 38.3 %, a 16384-byte one 34.6 %.

On top of that grid the EMU10K1 driver adds its own ~10.7 ms quantum: it
services fragments from a timer rather than a DMA interrupt, so a descriptor
is retired at the first tick after it finishes.  Fitting a grid to the
intervals finds 10.7 ms with a residual of 0.083 ms, and the four peaks are 8,
9, 13 and 14 of those ticks -- which is the same two-or-three descriptors,
seen through the timer.  A driver with a real per-fragment interrupt would not
show that second quantum, and nothing here depends on it.

## 3. The reserve, measured (`mode 2`)

One stall of S ms is inserted before a submission, every 41 buffers, so each
stall is isolated and the queue recovers in between.  15 to 31 stalls per run.

| buffer (frames) | AHEAD | first region | reserve (measured) |
|---|---|---|---|
| 5512 (125 ms) | 3 | as shipped | **85 - 90 ms** |
| 5512 | 3 | 4096 frames | **120 - 140 ms** |
| 5512 | 4 | as shipped | **180 - 220 ms** |
| 2756 (62.5 ms) | 3 | as shipped | **under 100 ms** (starves badly) |
| 2756 | 6 | as shipped | **under 160 ms** |
| 2756 | 6 | 4096 frames | **160 - 220 ms** |

Read the shipped row against the backend's own comment: **85-90 ms where it
claims 250**.  The full sweep is the table at the end of this file.

### What that means for a game

glquake's measured frame is 165-176 ms.  The shipped reserve is 85-90.  A
frame's worth of lateness cannot fit, so the pipeline runs dry -- which is
the stutter, and it is structural rather than a matter of tuning.

### Why openstep.3's freq/16 experiment had to fail

`freq/16` with `AHEAD 3` is 125 ms of reserve by the backend's arithmetic.
By the measured constant it is **negative**, and the measurement agrees: at
`2756 / AHEAD 3` even a 100 ms stall inserts 41 ms of silence a time.  That
release measured 3.7 % of the device's time dry with an idle main thread and
could not explain it; this is the explanation.

## 4. The first region sets the lead -- candidate fix A1, validated

The model said the kernel takes its descriptor lead from whatever is queued
when DMA starts and then holds it, so a first buffer of exactly two
descriptors should buy one descriptor of reserve.  It does:

| | stall 100 ms | stall 120 ms | stall 140 ms |
|---|---|---|---|
| first region as shipped | 8.9 ms silence | 8.9 | 15.1 |
| first region 4096 frames | **none** | **none** | 9.9 |

+35 to +50 ms of reserve, which is one descriptor (46.44), for a first
submission of a different size.  No latency cost: the queue depth does not
change.  It holds at the other geometry too -- `2756 / AHEAD 6` goes from
starving at a 160 ms stall to surviving it.

## 5. The constant, and what it predicts

    reserve = (AHEAD - 1) x buffer  -  C

    C = 160-165 ms  as shipped        (kernel lead + notification chain)
    C = 110-130 ms  with A1

`C` is a property of the kernel and the chain, not of the buffer size, so it
predicts across geometries -- and that prediction was then measured at
`freq/16`, where all four outcomes came out as predicted (starves at 160
without A1, survives 160 with it, starves again at 220, and `AHEAD 3` starves
even at 100).

| configuration | latency | reserve | survives a 176 ms frame |
|---|---|---|---|
| freq/8, AHEAD 3 (shipped) | 375 ms | 85-90 | no |
| freq/8, AHEAD 3 + A1 | 375 ms | 120-140 | no |
| freq/8, AHEAD 4 | 500 ms | 180-220 | yes |
| **freq/16, AHEAD 6 + A1** | **375 ms** | **160-220** | **yes** |
| freq/16, AHEAD 7 + A1 | 437 ms | 220-280 | yes |

The fourth row is the interesting one: the same latency the library ships
today, with about twice the reserve.

## Files

`mode1-5512.txt` is the no-stall baseline (section 2).  `m2-a3.txt` and
`m2-a4.txt` are the first decisive pair (160 ms stalls at AHEAD 3 and 4, 100
seconds each).  `sw-*` is the sweep of section 3, `b-*` and `c-*` the
first-region tests of section 4, `e-f16*` the `freq/16` confirmation of
section 5.  Each file is `k  wait_return_us  stall_ms_taken_after`, with the
run's parameters in the `#` header.

## What is NOT established here

- The measurement is on the EMU10K1 driver.  The descriptor geometry is the
  kernel's (`AudioChannel initOnDevice:` sets it from `page_size`, and the
  driver's own log confirms 65536 / 8 x 8192), so `C` should carry to the
  AC'97 and ES1371 drivers -- but that has not been measured.
- How long a game actually delays the audio thread.  The reserve is now
  known; the demand is not.  That needs instrumentation inside the backend.
- Whether raising thread priority helps.  Untested; the reserve arithmetic
  says it cannot help while the reserve is smaller than one frame.

## ab/ -- the four-arm A/B of the two thread fixes (2026-09-09)

`ab/ab-<arm>-<game>.log` are the game runs of the analysis document's
section 2.6, made with the target's `snd-ab.sh`: arm 0 = yield mutex + no
priority (control), 1 = blocking mutex only, 2 = priority only, 3 = both
(the shipped default).  Each log ends with the backend's close-time report
(gap histogram, mutex wait totals, thread priority).  `mutexbuild.log` and
`relink.log` are the build that produced the measured library, whose
prepared source is byte-identical to this tree.

Two caveats.  `ab-0-water1.log` is NOT the 1103-buffer control run the
table quotes -- a later 36-buffer run overwrote it; the control numbers
survive only in the document.  `ab-2-water1.log` is the run that crashed
with no core (csh's default coredumpsize is 0); it is treated as a
one-off for now and `test/openstep/snd-crash.sh` exists to reproduce it
with a core when that is wanted.  The quake logs' network-init line had
the host name masked.
