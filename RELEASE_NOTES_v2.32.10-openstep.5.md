# OPENSTEP SDL2 2.32.10 — openstep.5

Fifth OPENSTEP 4.2 Intel i486 release of upstream SDL 2.32.10.

**Audio now goes to SoundKit as one stream instead of one sound per
buffer.** openstep.4's notes ended by saying that avoiding libsound per
buffer "is a different library". This is that change, and the two
defects that came with it, found and fixed before release.

**Applications built against openstep.4 must be relinked.** The library
is static.

## What changed

### One `NXPlayStream` instead of one `SNDStartPlaying` per buffer

Measured on the machine with a 440 Hz tone and no load, ten blind
trials: the per-sound queue broke the tone up on every trial, while the
same buffers written to one `NXPlayStream` played clean after a blip at
the very start. The backend now keeps a ring of buffers, hands each to
the stream, and does not touch it again until SoundKit reports it
finished.

It is the default. `SDL_OPENSTEP_AUDIO_API=sound` selects the per-sound
path of openstep.4, unchanged.

### Every SoundKit message is sent by one thread

Foundation's `NSThread` specification says: *do not use `cthread_fork()`
to create a thread that executes an Objective-C message.* SDL's threads
are cthreads, and the first build of this release made its SoundKit
calls — and the autorelease pool around each — on SDL's audio thread.
GLQuake died in 3 runs of 30, right after its audio device started, with
`message addObject: sent to freed object`: the audio thread's pools and
the main thread's shared Foundation's single-threaded pool stack.

All SoundKit messages on the stream path are now sent by one `NSThread`,
detached once and kept for the life of the process. The other threads
hand it requests in plain C (cthreads mutex and condition). The one
Objective-C message sent elsewhere is the detach itself, from the thread
that first opens a stream device — normally the main thread.

### Submissions are not waited for

The second build waited for the SoundKit thread to finish each
`playBuffer`. That round trip cost the audio thread 3.5 ms a buffer (18.8
at the 90th percentile). A game that holds the audio lock for a whole
frame, as GLQuake does, leaves only a short gap between frames for the
callback, and the wait missed it: the device ran dry twice as often.

Opening and closing still wait for their answer; a submission is queued
and the audio thread goes straight back. The SoundKit thread takes the
requests in order and records each submission's outcome itself; a
refused `playBuffer` is reported on the audio thread's next pass, as a
disconnect, as before.

### The delegate is never released

SoundKit's completion callbacks come on its own reply thread. The
delegate reads its owner under one process-wide lock, a close clears the
owner under that lock, and the delegate object itself is kept: SoundKit
may still hold a pointer it read before `setDelegate:nil`.

### Software windows present only what changed

`SDL_UpdateWindowSurfaceRects` now displays the union of the rectangles
instead of the whole window. Measured with a game sending about nine
small updates a second, whole-window presents coincided with 51 of 54
long `SNDStartPlaying` stalls. The first present after the surface is
created, a bounds/size mismatch mid-resize, and the GL path all still
present the whole window.

## Measured

`glquake_radeon` (sdl2quake 1.4) at 640x480, 300 frames of `+map start`,
sound on, 60 runs as root after installing the packages:

| | first openstep.5 build | waited submissions | released |
|---|---|---|---|
| runs ending abnormally | 3 of 30 | 0 of 60 | **0 of 60** (and 0 of 30 traced) |
| times the device ran dry, per run | 2.93 | 6.77 | **2.82** |
| `sent to freed object` | yes | 0 | **0** |

The released build matches the first build's dry count (Mann-Whitney
p = 0.91) and has none of its crashes. `squake` for 45 s: 709 buffers,
every refill under 25 ms, never dry. As an ordinary user, six more runs:
all normal.

What is still heard is at load time: GLQuake holds the audio lock for
each frame, and a loading frame is longer than the queue — every build
before this one has the same gaps there.

## Diagnostics

- `SDL_OPENSTEP_AUDIO_REPORT=1` — the close-time report, now with the
  stream's submitted/started/completed counts, stale callbacks, SoundKit
  underruns, times the queue was seen empty, timeouts and failures.  A
  submission time in it is the queueing only.
- `SDL_OPENSTEP_AUDIO_TRACE=<path>` — writes `<path>.<pid>.<n>` at each
  close: one line per buffer (entry, previous wait return, in-flight
  count, reservation, the SoundKit thread's pick-up and finish, the
  wait) and one per completion, plus the SoundKit and reply threads'
  priorities. Nothing is allocated when it is not set.

## Installer packages

- `OpenStepSDL2Libraries.pkg` — static `libSDL2.a`.
- `OpenStepSDL2Headers.pkg` — public headers (unchanged from openstep.4),
  `SDL_openstepglpresent.h`, and documentation.
- `OpenStepSDL2Demos.pkg` — demo source, assets, rebuild scripts and i386
  binaries.

Extract the outer `.pkg.tar.gz` and open the contained `.pkg` with OPENSTEP
Installer. `SHA256SUMS` lists every archive.

## Scope and limitations

As openstep.4. Playback only through SoundKit; no capture; software
surfaces in a window, OpenGL through a registered accelerated Mesa
(Matrox G450 or ATI Radeon 9250) or stock Mesa otherwise.
`docs/PLAN_RELEASE_OPENSTEP5.md` carries the whole investigation,
including the two hypotheses that were wrong.
