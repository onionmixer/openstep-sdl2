# Installed SDL2 Demos package test record — 2026-08-17

Test prefix: `/LocalDeveloper` on OPENSTEP 4.2 i486.  The final test used the
reinstalled `OpenStepSDL2Demos.pkg` together with the installed SDL2 Libraries
and Headers packages; Mesa Libraries and Headers were installed at the same
prefix for the GL demo.

| Demo | Installed-binary result | Evidence |
| --- | --- | --- |
| `sdl2_clear` | PASS | GCD-visible software-renderer window started and automatically exited after two seconds without output or a remaining process. |
| `testgl11cube` | PASS | GCD-visible rotating rainbow cube was observed and closed. Its log reports `Version : 1.2 Mesa 3.4.2`, a 16-bit depth buffer and 21.05 FPS. |
| `testspriteminimal` | PASS | GCD-visible moving sprites were observed; Escape/window close left no process or error output. |
| `testmultiaudio` | PASS | The installed binary selected `openstep`, played `System audio output device`, then completed the all-devices pass with `All done!`. |
| `testthread` | PASS | Both child lifecycles retained independent TLS values; join and SIGTERM cleanup completed with no remaining process. |
| `testtimer` | PASS | The monotonicity, single/multiple timer and removal phases completed; the final log measured a one-second delay at 1001 ms ticks and 1001.942 ms performance-counter time. |

The first audio run exposed a packaging error: the unmodified consumer opens
`sample.wav` from its current directory, while the package had placed it only
under `Upstream/`. The same rule applies to sprite `icon.bmp`. The corrected
Demos package places both files at its execution directory and retains copies
beside the upstream source. The current SDL 2.32 `testgl2` was deliberately
removed from Demos because it correctly rejects Mesa 3.4.2's GL 1.2 surface;
the verified official SDL 2.0.0 fixed-function source is shipped instead as
`testgl11cube`.

After runtime tests, the installed demo sources rebuilt successfully using only
`/LocalDeveloper`:

```text
csh -f build-sdl2-clear.csh /LocalDeveloper
csh -f build-upstream-demos.csh /LocalDeveloper
# PASS: sdl2_clear testgl11cube testspriteminimal testmultiaudio testthread testtimer
```
