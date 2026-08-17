# OPENSTEP Mesa 3.4.2 payload manifest

Package roots: `OpenStepMesa342Libraries.pkg`, `OpenStepMesa342Headers.pkg`,
`OpenStepMesa342Demos.pkg`
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

## Installed payload, separated by package

```text
OpenStepMesa342Libraries.pkg
    Libraries/libGL.a
    Libraries/libGLU.a
    Tools/OpenStepMesa342-Intel

OpenStepMesa342Headers.pkg
    Headers/GL/{gl.h,glext.h,glu.h,glu_mangle.h,osmesa.h}
    Documentation/OpenStep-Mesa-3.4.2/{README.OPENSTEP,COPYRIGHT,COPYING,
        PORT-NOTES.md,LINKING.md,RELEASE-MANIFEST.txt}
    Tools/OpenStepMesa342Headers-Intel

OpenStepMesa342Demos.pkg
    Examples/OpenStep-Mesa-3.4.2/OSMesaClear/{osmesa-clear.c,
        build-osmesa-clear.csh,osmesa-clear}
    Examples/OpenStep-Mesa-3.4.2/MesaView/{MesaView.m,MesaView_main.m,
        MesaView.h,mesadraw.c,mesadraw.h,vect3d.c,vect3d.h,
        build-mesaview.csh,MesaView}
    Examples/OpenStep-Mesa-3.4.2/MesaView/English.lproj/MesaView.nib/
    Tools/OpenStepMesa342Demos-Intel
```

`glu.h` unconditionally includes `glu_mangle.h`; `gl.h` includes `glext.h`.
They are therefore part of the required public header closure.  `osmesa.h`
includes `GL/gl.h` and is installed as the supported software-rendering API.

## Explicit exclusions

- `glx.h`, `xmesa*.h`, X11 sources and all GLX/Xlib dependencies.
- GLUT, all Mesa demos and old AppKit examples **except** the listed original
  MesaView source/resources/binary, hardware-specific drivers and platform
  headers for Windows, DOS, MGL, SVGAlib, 3Dfx or BeOS.
- a separate `libOSMesa.a`: Mesa 3.4.2 OPENSTEP supplies OSMesa in `libGL.a`.
- compiler objects, generated dependency files, tests and source files.

## Mandatory package checks

1. Every listed file exists in its designated package, is a regular file and
   has the expected mode.
2. `ar t Libraries/libGL.a` contains `osmesa.o`; target `nm` finds
   `OSMesaCreateContext` in that member.
3. A new consumer compiled after Libraries and Headers are installed with only
   `-I<prefix>/Headers` and
   `-L<prefix>/Libraries -lGL -lm` completes the OSMesa smoke.
4. A GLU consumer builds with `-lGLU -lGL -lm`.
5. `lsbom` decoded output contains every payload manifest file and no source
   tree, host file or SDL file. The historical Installer may also record
   ancestor directories; their delete behavior is tested separately.
6. The Libraries package contains executable `OpenStepMesa342Libraries.post_install`;
   after Installer extraction it runs `ranlib` on both static archives. This
   is mandatory because the target archive index records its pathname and is
   stale after a package copy.  Every package has its own i386-only marker and
   `pre_install` check.
