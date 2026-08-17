# OPENSTEP SDL 2.32.10 payload manifest

Package roots: `OpenStepSDL2Libraries.pkg`, `OpenStepSDL2Headers.pkg`,
`OpenStepSDL2Demos.pkg`
Default Installer prefix: `/LocalDeveloper` (relocatable)

## Inputs that must be produced afresh on OPENSTEP

```text
/tmp/.../SDL-2.32.10-openstep/include/  # final target-generated header tree
/tmp/.../SDL-2.32.10-openstep/libSDL2.a # final archive after ranlib
```

The generator must start with a clean source stage and run the final archive
rebuild.  The package input archive must pass
`check-final-api-manifest.csh` with all 836 required API symbols.  The header
input is the target-generated tree, not a host-preprocessed tree and not the
unmodified upstream `include/` directory.

## Installed payload, separated by package

```text
OpenStepSDL2Libraries.pkg
    Libraries/libSDL2.a
    Tools/OpenStepSDL2-Intel

OpenStepSDL2Headers.pkg
    Headers/SDL2/<all public SDL 2.32.10 headers>
    Headers/SDL2/SDL_config.h
    Headers/SDL2/SDL_config_openstep.h
    Headers/SDL2/stdint.h
    Documentation/OpenStep-SDL2-2.32.10/{README.OPENSTEP,API-COVERAGE.md,
        PORT-NOTES.md,LINKING.md,LICENSE.txt,RELEASE-MANIFEST.txt}
    Tools/OpenStepSDL2Headers-Intel

OpenStepSDL2Demos.pkg
    Examples/OpenStep-SDL2-2.32.10/sdl2_clear.c
    Examples/OpenStep-SDL2-2.32.10/{build-sdl2-clear.csh,build-upstream-demos.csh}
    Examples/OpenStep-SDL2-2.32.10/{sdl2_clear,testgl2,testspriteminimal,
        testmultiaudio,testthread,testtimer}
    Examples/OpenStep-SDL2-2.32.10/Upstream/{testgl2.c,testspriteminimal.c,
        testmultiaudio.c,testthread.c,testtimer.c,testutils.c,testutils.h,
        icon.bmp,sample.wav}
    Examples/OpenStep-SDL2-2.32.10/Support/{SDL_test_common.c,
        SDL_test_assert.c,SDL_test_log.c,SDL_test_font.c,SDL_test_memory.c,
        SDL_test_crc32.c}
    Tools/OpenStepSDL2Demos-Intel
```

`<all public SDL 2.32.10 headers>` means every ordinary `*.h` in the upstream
`include/` directory **except** the foreign platform configuration templates
`SDL_config_android.h`, `SDL_config_emscripten.h`, `SDL_config_iphoneos.h`,
`SDL_config_macosx.h`, `SDL_config_minimal.h`, `SDL_config_ngage.h`,
`SDL_config_os2.h`, `SDL_config_pandora.h`, `SDL_config_windows.h`,
`SDL_config_wingdk.h`, `SDL_config_winrt.h` and `SDL_config_xbox.h`.

The generator copies the matching normal public headers from the clean target
header tree, then explicitly supplies the OPENSTEP `SDL_config.h`,
`SDL_config_openstep.h` and `stdint.h` compatibility wrapper.  It does not
replace `SDL_config.h` with an upstream template.

## Explicit exclusions

- Mesa headers, libraries and source.  Mesa remains a separately installed,
  optional dependency for SDL OpenGL consumers only.
- all remaining SDL source and tests, build objects, target logs, `.app`
  probes and host tools.  The specifically listed demo and SDL test support
  sources are intentional Demos-package payload.
- shared/dynamic SDL libraries; this release is `libSDL2.a` only.
- non-OPENSTEP SDL configuration templates named above.

## Mandatory package checks

1. `check-final-api-manifest.csh` against the Libraries payload archive reports
   836 API symbols.
2. A consumer containing `#include <SDL2/SDL.h>` compiles with only
   `-I<prefix>/Headers` and the package archive/framework link line.
3. Libraries plus Headers installed at one prefix pass a 2D window/renderer
   consumer.
4. With the Mesa package installed at the same prefix, an SDL
   `SDL_WINDOW_OPENGL` consumer links with `-L<prefix>/Libraries -lGL -lm` and
   completes the GL 1.2 context/swap test.
5. `lsbom` decoded output contains every payload manifest file and no Mesa,
   source tree, host file or target log. The historical Installer may also
   record ancestor directories; their delete behavior is tested separately.
6. Each package's i386-only marker is visible through `lsbom -arch i386` and
   absent from `lsbom -arch m68k`; every `pre_install` refuses a non-i386
   target.
