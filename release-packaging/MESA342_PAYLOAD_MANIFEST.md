# OPENSTEP Mesa 3.4.2 payload manifest

Package root: `OpenStepMesa342.pkg`  
Default Installer prefix: `/LocalDeveloper` (relocatable)

This is an **Intel i486-only** package.  Its `libGL.a` and `libGLU.a` contain
i386 Mach-O members produced by `cc -m486`, not fat/multi-architecture code.
The Installer title and distribution artifact name must retain that fact.

## Inputs that must be produced afresh on OPENSTEP

```text
Mesa-3.4.2/include/GL/gl.h
Mesa-3.4.2/include/GL/glext.h
Mesa-3.4.2/include/GL/glu.h
Mesa-3.4.2/include/GL/glu_mangle.h
Mesa-3.4.2/include/GL/osmesa.h
Mesa-3.4.2/lib/libGL.a
Mesa-3.4.2/lib/libGLU.a
```

The generator must first execute exactly:

```text
make CC='cc -m486' openstep
```

against a clean Mesa 3.4.2 OPENSTEP source stage.  `libGL.a` must contain
`osmesa.o` and the OSMesa entry points.  A prior `/tmp` build or an archive
from an already installed prefix is not an allowed input.

## Installed payload

```text
Headers/GL/gl.h
Headers/GL/glext.h
Headers/GL/glu.h
Headers/GL/glu_mangle.h
Headers/GL/osmesa.h
Libraries/libGL.a
Libraries/libGLU.a
Documentation/OpenStep-Mesa-3.4.2/README.OPENSTEP
Documentation/OpenStep-Mesa-3.4.2/COPYRIGHT
Documentation/OpenStep-Mesa-3.4.2/COPYING
Documentation/OpenStep-Mesa-3.4.2/PORT-NOTES.md
Documentation/OpenStep-Mesa-3.4.2/LINKING.md
Documentation/OpenStep-Mesa-3.4.2/RELEASE-MANIFEST.txt
```

`glu.h` unconditionally includes `glu_mangle.h`; `gl.h` includes `glext.h`.
They are therefore part of the required public header closure.  `osmesa.h`
includes `GL/gl.h` and is installed as the supported software-rendering API.

## Explicit exclusions

- `glx.h`, `xmesa*.h`, X11 sources and all GLX/Xlib dependencies.
- GLUT, Mesa demos, the old AppKit examples, hardware-specific drivers and
  platform headers for Windows, DOS, MGL, SVGAlib, 3Dfx or BeOS.
- a separate `libOSMesa.a`: Mesa 3.4.2 OPENSTEP supplies OSMesa in `libGL.a`.
- compiler objects, generated dependency files, tests and source files.

## Mandatory package checks

1. Every listed file exists, is a regular file and has the expected mode.
2. `ar t Libraries/libGL.a` contains `osmesa.o`; target `nm` finds
   `OSMesaCreateContext` in that member.
3. A new consumer compiled with only `-I<prefix>/Headers` and
   `-L<prefix>/Libraries -lGL -lm` completes the OSMesa smoke.
4. A GLU consumer builds with `-lGLU -lGL -lm`.
5. `lsbom` decoded output contains every payload manifest file and no source
   tree, host file or SDL file. The historical Installer may also record
   ancestor directories; their delete behavior is tested separately.
6. Package root contains executable `OpenStepMesa342.post_install`; after
   Installer extraction it runs `ranlib` on both static archives. This is
   mandatory because the target archive index records its pathname and is
   stale after a package copy.
