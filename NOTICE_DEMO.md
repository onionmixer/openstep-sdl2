# OPENSTEP SDL2 Demos notice

`OpenStepSDL2Demos.pkg` installs its examples below
`/LocalDeveloper/Examples/OpenStep-SDL2-2.32.10/`.  Install the SDL2
Libraries and Headers packages at the same prefix first.  All binaries are
target-built i386 executables; source and rebuild scripts are shipped beside
them.

| Demo | Type | What it verifies | How it ends |
| --- | --- | --- | --- |
| `sdl2_clear` | SDL 2D / software renderer | window creation, software renderer, clear/present and teardown | automatically after two seconds |
| `testgl11cube` | SDL OpenGL / Mesa | rotating fixed-function GL 1.1 cube, context creation and swap | Escape or window close |
| `testspriteminimal` | SDL 2D / software renderer | textured sprite rendering and event pump | Escape or window close |
| `testmultiaudio` | SoundKit audio | default output-device enumeration and WAV callback playback | automatically after its playback passes |
| `testthread` | threading | TLS, cthreads lifecycle, join and SIGTERM cleanup | automatically, about ten seconds |
| `testtimer` | timers | tick monotonicity, multiple timers, removal and performance counter | automatically, about 26 seconds |

`testgl11cube` is the byte-preserved official SDL 2.0.0 `testgl2` source,
renamed only to distinguish it from SDL 2.32's current `testgl2`.  The current
sample eagerly loads modern OpenGL entries that Mesa 3.4.2 correctly does not
export; it is therefore not a runnable demo for this GL 1.2 release.

The SDL OpenGL cube requires `OpenStepMesa342Libraries.pkg` and
`OpenStepMesa342Headers.pkg` at the same prefix.  `icon.bmp` and `sample.wav`
are intentionally present at the demo execution directory because the
unmodified sprite and audio consumers resolve those assets from their current
directory.  Rebuild all selected upstream demos in that directory with:

```text
csh -f build-upstream-demos.csh /LocalDeveloper
```
