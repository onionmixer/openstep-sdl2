# SDL 2.32.10 for OPENSTEP 4.2 — target-first port plan

Created: 2026-08-15  
Status: **active — Phase 0 passed; Phase 1 core/atomic/thread bootstrap in progress (`src/SDL.c` object gate passed)**

## 1. Objective and non-negotiable scope

Produce a static, native `libSDL2.a` for Intel OPENSTEP 4.2 that ports SDL
2.32.10 rather than defining an OpenStep-specific SDL subset. The delivered
library must preserve SDL2's public API, ABI and documented semantics wherever
the target has a corresponding capability. It must use AppKit, Display
PostScript, SoundKit, BSD and Mach cthreads; it must not require X11, an X
server, pthreads, LLVM, CMake, Meson or a modern Objective-C runtime.

Every public SDL2 function must be present in the final library. Where
OPENSTEP lacks the relevant hardware or OS facility (for example sensors), it
must implement SDL's ordinary no-device/unsupported result semantics, not be
removed, renamed or silently replaced by a private API. No OpenStep-only
public extension is part of the deliverable. Mesa 3.4.2 is the OpenGL 1.2
implementation path for the standard SDL GL API.

## 2. Fixed upstreams and source policy

| Component | Selected source | Why | Policy |
|---|---|---|---|
| SDL2 | `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71` | latest SDL2 release selected for this project | pristine source under `upstream/`, OPENSTEP changes only in `port/openstep/` |
| Mesa/OSMesa 3D spike | Mesa 3.4.2, official `MesaLib-3.4.2.tar.gz`, SHA-256 `b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6` | stable release with an explicit OPENSTEP target, `OpenStep/` AppKit examples and OSMesa compiled into static `libGL.a` | isolated third-party source; no installation into the system; link only static libraries |

Mesa 3.4.2 is the selected stable maintenance release.  Its source contains
the actual `openstep` make target, `-traditional-cpp -DOPENSTEP` flags,
`mklib.openstep`, the historical `OpenStep/` AppKit examples and OSMesa.
The source tree contains no LLVM or llvmpipe file/name.  Its `openstep`
target places OSMesa entry points in `libGL.a`, rather than producing a
separate `libOSMesa.a`.  This is an evidence-based compatibility choice, not
a claim that Mesa 3.4.2 is a modern renderer.

Do not substitute a current Mesa release.  Current software renderers such as
llvmpipe are LLVM/JIT based and are unsuitable for OPENSTEP's compiler and
runtime.  Do not copy a Linux-built Mesa binary to OPENSTEP.

## 3. Reuse contract from the completed SDL 1.2 port

The SDL1 code is a behavioural reference, not a source drop-in.  Reuse its
proven target facts and keep its source separate.

| Existing SDL1 result | SDL2 design use | SDL2-specific addition |
|---|---|---|
| AppKit `NSWindow`/`NSView`, DPS bitmap presentation and one-time row reversal | `SDL_Window` native object and window-surface presentation | `CreateWindowFramebuffer`, `UpdateWindowFramebuffer`, `DestroyWindowFramebuffer`; `SDL_Renderer` software path |
| `NSEvent` translation, focus/expose/close, native cursor and DPS warp | SDL2 window, keyboard, text-input and mouse event plumbing | SDL2 scancode/keycode, window-event IDs, multi-window routing |
| SoundKit `SNDStartPlaying(..., preempt=0)` FCFS queue | SDL2 audio device callback and bounded PCM ownership | SDL2 device pause/close, format negotiation and thread lifetime |
| BSD `gettimeofday`/`select`/`setitimer` | SDL2 timer and delay layer | SDL2 counter/performance APIs and 64-bit API emulation policy |
| Mach cthreads, semaphore/condition fallback | SDL2 thread/mutex/semaphore/condition layer | TLS, atomics and SDL2 thread lifecycle |

Use a project-specific target tree only:

```text
/ndrv/openstep-sdl20/       host-managed, read-only NFS source
/tmp/SDL20/src/             staged source
/tmp/SDL20/build/           objects and static archives
/tmp/SDL20/bin/             test executables and app wrappers
/tmp/SDL20/log/             target evidence
/tmp/SDL20/mesa/            staged Mesa source and static Mesa archives
```

Staging may delete and recreate only `/tmp/SDL20`.  It must never write below
the NFS tree or use a generic `/tmp` cleanup.

## 4. Phase 0 — target inventory and reproducible staging

1. Record the target's `cc` version, headers, `ar`/`ranlib`, `make`, shell,
   `/NextDeveloper` paths and CPU subtype behaviour.
2. Probe and preserve the exact declarations for AppKit/DPS, SoundKit,
   `cthreads.h`, `gettimeofday`, `select`, `setitimer`, `dlopen`, `stdint.h`
   and compiler atomic/TLS capabilities.
3. Add source records, licenses and hashes.  Import pristine SDL and Mesa
   sources only after hash verification.
4. Write `stage-openstep.csh`, `prepare-openstep-tree.csh` and a single
   `/tmp/SDL20` cleanup rule modelled on SDL1's safe staging scripts.

**Pass gate:** a clean NFS stage creates `/tmp/SDL20/{src,build,bin,log,mesa}`
without source-tree writes; probe output is retained under `notes/`.

**2026-08-15 checkpoint:** the real OPENSTEP 4.2 i486 target confirmed
`cc-744.13`/GCC 2.7.2.1, the required AppKit/SoundKit/cthreads headers and a
successful `-m486` Objective-C framework compile. It also proved that
`stdint.h` and compiler TLS (`__thread`) are absent, and `__sync` atomic
builtins fail to link. Direct Telnet mounting with the NFS server's accepted
real workspace path succeeded, and the safe staging script passed. Full
commands and outputs are recorded in `notes/TARGET_INVENTORY_20260815.md`.

## 5. Phase 1 — SDL2 compiler-compatibility bootstrap (blocking)

SDL 2.32.10 is not a C89/GCC 2.7 drop-in.  Create a small compatibility
overlay and compile a deliberately minimal static source set first.

- Supply fixed-width integer and format compatibility headers only where the
  target lacks them; preserve SDL2 public ABI widths.
- Replace or isolate C99 syntax, modern libc assumptions, unsupported
  builtins and allocator TLS only after each instance is demonstrated on the
  target.  Keep each category in a separate patch.
- Implement an OPENSTEP atomic fallback using locks if GCC atomic builtins are
  unavailable.  Do not claim lock-free atomics.
- Port SDL2 TLS on top of verified cthreads primitives, or disable only APIs
  that cannot be made ABI-correct.  Threads must not silently use SDL's dummy
  thread backend.
- Use an explicit old-make static archive build; do not run target CMake,
  Meson or regenerated modern autoconf.
- Compile with `-m486`, then apply the existing narrowly scoped Mach-O i486
  subtype fix to every executable.

**Compiler-gate pass:** a clearly named prototype archive may compile and run
the headless core checks (error/string, timer/delay, atomics, TLS, thread
create/join, mutex recursion, semaphore and condition). It is never named
`libSDL2.a`, installed or presented as a port.

**Port pass gate:** final `libSDL2.a` exports every SDL 2.32.10 public runtime
symbol and passes the API/behaviour matrix in `notes/API_COVERAGE.md`,
including init/quit, video/events/rendering, audio, input, file/RWops,
thread/timer, OpenGL and target-appropriate no-device paths.

**Export-gate implementation:** generate the 836-symbol OpenStep dynapi
baseline with `build/generate-api-manifest-host.sh`, then run
`build/check-final-api-manifest.csh` against the target final archive. The
checker normalizes the target Mach-O external-symbol underscore before
comparison. This is a necessary export check, followed by the separate
public-header and behaviour audits in `notes/API_COVERAGE.md`.

**Dispatcher integration order:** `src/SDL.c` and `SDL_assert.c` now compile
on the target as separate objects. Do not force an early `SDL_Init` link by
stubbing their event/video/audio references: the real assertion path itself
uses window/message-box services. Integrate the actual OpenStep video/event
backend first, then its software renderer and message-box path, followed by
SoundKit audio; link the upstream dispatcher only when these concrete
dependencies exist.

**Video-core checkpoint:** the upstream video core now compiles on the target
with `SDL_VIDEO_DRIVER_OPENSTEP` and imports `_OPENSTEP_bootstrap`. The
private staging transform changes only GCC 2.7's rejected empty macro
arguments into an empty-expanding token; it does not change return values or
the upstream source export. This remains an object gate until native window,
framebuffer and event callbacks are implemented and linked.

**Stop rule:** if compatibility requires a broad mechanical rewrite of the
whole SDL2 release, pause and decide whether to pin an older SDL2 baseline;
do not hide that divergence inside unreviewable generated source.

**First implementation slice:** `port/openstep/include/SDL_config_openstep.h`
supplies only the Phase 0-proven legacy libc and integer-width facts. Its
paired `test/openstep/header-smoke.c` must compile on the target before any
SDL source is accepted into the compiler-gate prototype. This is not a claim
that final `libSDL2.a` now compiles.

**2026-08-15 header gate:** passed. The overlay uses OPENSTEP BSD
`intN_t`/`u_intN_t` rather than a nonexistent `stdint.h`, disables unsupported
format-analysis attributes, and avoids GCC 2.7's packed-attribute syntax in
the i386 `SDL_AudioCVT` declaration. `header-smoke.c` compiled with
`cc -m486 -D__OPENSTEP__` and verified all SDL integer widths and pointer
width. The next task is source-level C89 conversion, not a backend yet.

The first source-level probe is deliberately `SDL_error.c`: it exercises
internal configuration, varargs and error-buffer declarations without adding
video, audio or cthreads. Its private build overlay disables SDL's dynamic API
because this static OPENSTEP build has no `dlopen` contract.

`SDL_vacopy.h` is also an explicit overlay: SDL 2.32.10 maps GCC before 3 to
the unavailable `__va_copy` builtin, while a target probe verifies that this
OPENSTEP i386 `va_list` can be assigned. The overlay therefore defines
`va_copy(dst, src)` as assignment and every compile gate must remain warning
free for that symbol.

Before adding a cthreads thread backend, compile and execute the isolated
`atomic-smoke` link test. SDL2's own non-`__sync` path uses its i386 spinlock
assembly for lock acquisition and a lock-striped CAS emulation. The test must
prove that path on the real CPU; it must not be inferred from object compile.

The target is an i486, not merely generic i386: SDL's GNU-i386 `pause`
mnemonic is rejected by the target assembler. The private header overlay must
use a `nop` spin hint only for `__OPENSTEP__ && __i386__`; it must not alter
the upstream path for later x86 processors.

The SDL1 cthreads backend is a behavioural reference only. Before copying any
of its ownership or timeout logic, a standalone target test must create,
join and mutex-lock a cthread. Its link line is intentionally bare `cc`: the
test records whether OPENSTEP exposes cthreads through the default toolchain
without inventing a host library dependency.

The first SDL2 native-backend run test deliberately substitutes only
`SDL_RunThread`, error reporting and delay symbols. It validates the new
cthread handle ABI, one-time initialization, create/join, status propagation
and native ID on the target. It is not an SDL_CreateThread API test: that
requires the complete allocator, mutex and TLS link set.

The OPENSTEP SDL mutex must preserve SDL's recursive-owner contract over a
Mach `mutex_t`: `SDL_TryLockMutex` calls the documented nonblocking
`mutex_try_lock`, while regular lock/unlock uses cthreads. A target test must
cover recursive lock/unlock and concurrent increments before generic TLS can
rely on this mutex.

**2026-08-15 core/atomic checkpoint:** passed. The selected core batch
(`SDL_error`, list, dataqueue, utils, hints, log and string) compiles without
warnings. `atomic-smoke` links and runs SDL2's non-`__sync` path, exercising
set/add/get/CAS. Its i486 spin acquisition uses `lock xchg`; CAS is SDL's
lock-striped emulation. This proves only the single-threaded operation. The
cthreads contention test remains a later, mandatory gate.

**2026-08-15 cthreads primitive checkpoint:** passed. A standalone bare-`cc`
target executable successfully called `cthread_init`, allocated/locked a Mach
mutex, forked a cthread and joined it. This establishes the primitive ABI,
not SDL2's thread lifecycle, TLS, semaphore/condition timeout semantics or
contention correctness.

**2026-08-15 cthreads contention checkpoint:** passed. Four cthreads blocked
on a condition, were released by broadcast, performed 40,000 mutex-protected
increments and joined with the exact count.

**2026-08-15 SDL2 thread/mutex checkpoint:** passed at the native-backend
level. The new cthreads backend compiles and its isolated create/join/status/
ID test runs. The new SDL mutex passes recursive `Lock`/`TryLock`/`Unlock` and
two-worker contention.

**2026-08-15 SDL2 semaphore checkpoint:** passed. The OpenStep semaphore owns
a Mach `mutex_t` and `condition_t`; its target smoke test covers initial-value
accounting, `TryWait`, a 10ms empty finite timeout, `SemWait` released by
`SemPost`, and final value accounting. Mach cthreads offers no timed condition
wait, so infinite waits use its native condition queue and finite waits release
the mutex and use a maximum one-millisecond `select()` delay before retrying.
That temporary policy is intentionally self-contained: it avoids claiming the
unported SDL2 timer layer as a dependency. It must be revisited when the timer
backend is available, but it is adequate for the current API gate.

This remains deliberately short of declaring full thread support: the public
thread/TLS core must next be stressed under repeated concurrent lifecycle
workloads and then joined to the complete timer and `SDL_Init` paths.

**2026-08-15 SDL2 condition checkpoint:** passed. The backend uses SDL's
semaphore-handshake condition algorithm over the now-tested OpenStep mutex and
semaphore implementations. Its target test verifies a 10ms timeout and that
the caller mutex is re-locked, followed by a single waiter released with
`Signal` and three independent waiters released with `Broadcast`; all workers
join and the final counters are exact. The executable completed the same test
20 consecutive times.

**2026-08-15 public SDL thread/TLS checkpoint:** passed. The actual
`SDL_CreateThread`/`SDL_WaitThread` implementation was linked with actual SDL
allocator, string, getenv, hint, log, error, atomics and generic-TLS sources;
there are no allocator, TLS or `SDL_RunThread` test replacements. `HAVE_MALLOC`
selects OPENSTEP libc allocation rather than SDL's pthread-requiring dlmalloc.
The target program checks a real one-millisecond `SDL_Delay`, main/child TLS
isolation, child destructor execution, worker ID, returned status, name
ownership and restored SDL allocation count after `SDL_QuitTLSData`. It passed
20 independent process executions. The program provides only the TLS body of
`SDL_InitMainThread` locally because whole `src/SDL.c` dispatches unported
timer/video/audio subsystems; it does not claim `SDL_Init` or `SDL_Quit`.

This link set uses a small OpenStep `SDL_stdlib_compat.c` only for the six
stdlib wrappers actually needed by this core subset (memset/memcpy and four
ctype operations), and compiles this release-style test with
`SDL_ASSERT_LEVEL=0`. Neither choice is a claim that the complete SDL stdlib
or assertion/UI subsystem has been ported. The initial `SDL_Delay` link
primitive has now been expanded into the bounded timer-core checkpoint below;
it is still separate from whole-library initialization.

**2026-08-15 SDL2 timer-core checkpoint:** passed. The OpenStep backend now
provides `SDL_TicksInit`/`SDL_TicksQuit`, `SDL_GetTicks64`, performance
counter/frequency and interruption-aware `SDL_Delay` over `gettimeofday` and
`select`. The actual upstream `SDL_timer.c` also links on the target and its
one-shot `SDL_AddTimer` callback runs and is cleanly joined by `SDL_TimerQuit`.
The test verifies a constructed timeval borrow/backward boundary helper, a
real 20ms tick advance, nondecreasing performance counter, the 1MHz frequency,
callback completion and post-quit tick reinitialization; it passed 20 process
executions. The backend clamps a backward `gettimeofday` sample under its
spin lock, but a controllable-clock test has not yet exercised that branch, so
clock-regression behaviour remains implementation evidence rather than a pass
claim. This still does not make whole `SDL_Init`/`SDL_Quit` available.

**2026-08-15 core-source checkpoint:** passed. `SDL_error.c` compiled to
`/tmp/SDL20/build/SDL_error.o` with `cc -m486 -D__OPENSTEP__`. It does not
link yet because its allocator, log and thread/error-buffer dependencies are
not part of this narrow probe.

## 6. Phase 2 — native video, window surfaces and 2D renderer

Implement `src/video/openstep/` as an SDL2 `SDL_VideoDevice` backend.

1. Register one desktop display and create a native AppKit application,
   `NSWindow` and presenter `NSView` for each SDL window.
2. Implement window title, show/hide, size/position, minimize/restore,
   resizable style, focus, close and display bounds. Implement desktop
   fullscreen through a borderless AppKit screen frame and preserve the
   prior native frame for restoration; explicitly do not claim unsupported
   exclusive display-mode switching.
3. Implement framebuffer allocation and dirty presentation through
   `CreateWindowFramebuffer`, `UpdateWindowFramebuffer` and
   `DestroyWindowFramebuffer`.  Preserve SDL top-left coordinates and apply
   the verified AppKit bitmap-row reversal exactly once.
4. Enable SDL's built-in software renderer only.  `SDL_RenderPresent()` must
   reach the same dirty presenter; do not enable SDL's OpenGL renderer.
5. Pump `NSEvent` in the AppKit thread and translate keyboard, mouse, wheel,
   focus, expose, resize and quit into SDL2 events. Route every native window
   to its corresponding SDL window; multi-window operation is a port
   requirement, not a later OpenStep extension.

**Pass gate:** target GUI tests cover `SDL_GetWindowSurface`, dirty partial
updates, `SDL_UpdateWindowSurfaceRects`, `SDL_CreateRenderer(...software...)`,
texture update/copy, alpha blend, render targets, expose, three resizes,
keyboard/mouse/quit and correct teardown.

## 7. Phase 3 — audio and core services

1. Port the SDL1 SoundKit queue design: SDL callback fills a mix buffer;
   backend owns 0.25-second PCM blocks, prequeues four blocks with
   `preempt=0`, retains at most eight, and reclaims only completed tags.
2. Start with 22050/44100 Hz, mono/stereo, signed-16 PCM.  Convert byte order
   before `SND_FORMAT_LINEAR_16`; reject unsupported requests explicitly.
3. Port the SDL1 timer semantics, including interrupted delay, wall-clock
   regression clamp and documented unsigned wrap arithmetic.
4. Complete cthreads-backed mutex/semaphore/condition/TLS/atomic tests under
   contention and repeated init/quit cycles.

**Pass gate:** audio pause/resume/close, 300-second audio-only, 300-second
audio+video, timer callback/delay/wrap, and threaded TLS/atomic contention
tests complete with retained logs and no leftover process.

## 8. Phase 4 — Mesa 3.4.2 OpenGL 1.2 standard-GL path

This phase begins only after the Phase 2 2D path is stable.

1. Stage Mesa 3.4.2 under the private persistent
   `/tmp/SDL20/mesa/Mesa-3.4.2` tree, build `make openstep` with the
   target `cc`, and verify static `libGL.a` and `libGLU.a`.  Verify the
   OSMesa symbols from `OSmesa/osmesa.c` are present in `libGL.a`; this Mesa
   release does not produce a separate `libOSMesa.a`.  Stage the verified
   gzip archive and extract it privately, rather than recursively reading
   the legacy source tree across NFS.  Use Mesa's
   `-traditional-cpp -DOPENSTEP` configuration; do not add X11, LLVM or
   dynamic GL libraries.
2. Build a standalone AppKit OSMesa probe before connecting SDL: create an
   RGBA context and caller-owned buffer, draw a fixed-function GL 1.2
   triangle/cube, and display it with the Phase 2 presenter.  The headless
   context/buffer/fixed-function-triangle/version, entry-point lookup,
   sharing, resize-bind and detach sub-gates have passed.  The AppKit display
   path is also validated when execution is dispatched through a `gcdsd`
   started from the logged-in Workspace Terminal session.
3. Add SDL GL support only after the probe passes: context creation/deletion,
   `MakeCurrent`, per-window RGBA storage, resize rebind, symbol lookup and
   `SDL_GL_SwapWindow` -> `glFinish` -> DPS dirty presentation.
   The source and GCC 2.7 object gates are now in place with static Mesa 3.4.2
   symbol resolution, and a standard SDL GL smoke is linked as i486. The real
   SDL GL window now creates, swaps and tears down through that AppKit
   WindowServer session; retain this as the regression gate.
4. Support only the advertised Mesa 3.4.2 OpenGL 1.2/fixed-function contract.
   Reject profile/version/ES requests above it.  Emulate double-buffering
   only if the buffer ownership and resize tests prove it safe.

**Pass gate:** the standalone probe and an SDL test create/destroy a context,
render, swap, resize, lose/regain focus and close without pixel orientation,
context-currentness or lifetime failures.  Capture `glGetString` results and
never advertise extensions not returned by the target library.

**Stop rule:** if Mesa 3.4.2's target build or probe fails, do not label a
2D-only archive as the SDL2 port or release `libSDL2.a`. Record the blocker
and do not replace OSMesa with a newer development Mesa or a modern Mesa/LLVM
stack without a new source-selection decision.

**Crash triage rule:** when a console SDL GL smoke fails, first run the
original MesaView application (with its ProjectBuilder-generated
`Resources/Info-nextstep.plist`) and its independent OSMesa renderer smoke.  A
passing MesaView renderer does not prove SDL's AppKit presentation path; it
does establish that Mesa GL/GLU and the original example renderer are not the
first failing layer.  Use the SDL smoke's flushed public-API checkpoints to
locate the next layer before changing Mesa or the public SDL API.

The OpenStep cthreads TLS backend must initialize the generic TLS mutex before
the first `SDL_GetError`/`SDL_SetError` path. This may precede `SDL_CreateThread`
and is therefore part of normal `SDL_Init` correctness, not a test-only setup
step. A NULL mutex must never be allowed to recurse through SDL error handling.

The compatibility OpenGL runtime gate is complete only when the standard SDL
path succeeds in the console AppKit session: `SDL_Init(SDL_INIT_VIDEO)`, an
`SDL_WINDOW_OPENGL` window, `SDL_GL_CreateContext`, entry-point lookup,
drawable-size and swap-interval behavior, `SDL_GL_SwapWindow`, make-current
detach/restore, and teardown. This gate passed with `GL_VERSION=1.2 Mesa 3.4.2`.

## 9. Phase 5 — compatibility, packaging and acceptance

- Build unmodified small SDL2 2D applications and an explicit GL-1.x-only
  sample.  Do not use an OpenGL renderer or shader-based sample as an initial
  acceptance test.
- Verify static linking against AppKit, Foundation, SoundKit and the Mesa
  static archives used for standard SDL GL. Inspect target dependencies to ensure
  X11, LLVM and host paths are absent.
- Keep upstream source, overlay patches, test sources, source hashes,
  capability matrix and target logs in the reproducible source package.
- State unsupported APIs in `README.md`; they must return failures rather
  than pretending to be accelerated or available.

**Final pass gate:** a clean NFS stage reproduces final `libSDL2.a` and the
test suite on the OPENSTEP machine. The retained evidence covers every runtime
public API group in `notes/API_COVERAGE.md`, including implemented backends
and SDL-standard unavailable-platform/device behaviour.
