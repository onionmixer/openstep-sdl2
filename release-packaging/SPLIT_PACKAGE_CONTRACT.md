# OPENSTEP SDK split-package contract

Each product is delivered as two independently installable OPENSTEP Installer
packages, analogous to a runtime/library package and a development headers
package.  They share the relocatable default prefix `/LocalDeveloper`.

| Product | Library package | Headers and examples package |
| --- | --- | --- |
| SDL 2.32.10 | `OpenStepSDL2Libraries.pkg` | `OpenStepSDL2Headers.pkg` |
| Mesa 3.4.2 | `OpenStepMesa342Libraries.pkg` | `OpenStepMesa342Headers.pkg` |

## Library packages

- Contain only static archives and the tiny i386 Mach-O Installer marker.
- SDL: `Libraries/libSDL2.a`.
- Mesa: `Libraries/libGL.a` and `Libraries/libGLU.a`.
- Are i386/i486-only: their BOM exposes the marker for i386 only and their
  `pre_install` hook rejects a non-i386 machine.
- Run `post_install` to rerun `ranlib` after extraction, because OPENSTEP's
  archive index records the pre-install pathname.

## Headers and examples packages

- Contain public headers, licenses, port/linking documentation and demos under
  `Examples/`. Each demo includes its source, target build script and a
  target-built i386 executable.
- Do not duplicate product archives. Each package contains its own tiny i386
  Mach-O Installer marker as well as the i386 demo binary, so its Installer
  BOM and `pre_install` policy reject non-Intel hosts.
- SDL demo is a timed 2D window/renderer smoke application.
- Mesa demo is an OSMesa OpenGL 1.2 source demo.
- Each demo ships with a C89/csh target build command and accepts an optional
  installation prefix. It requires both packages of its product to be
  installed at that prefix.

## Installation and test order

1. Install the product's `Libraries` package at a selected prefix.
2. Install its `Headers` package at the identical prefix.
3. Build the source demo from `Examples/` with that prefix.
4. SDL OpenGL demos additionally require both Mesa packages at that prefix.

Library and Headers packages have separate receipts and deletion scopes.  No
package may install the other package's files.

## Source-control rule

Every release commit includes the package `.info` metadata, build and verify
scripts, Installer hooks, architecture-marker source, demo source and demo
build scripts. Target-built `.pkg` directories and `/tmp` stages are release
artifacts, not source-controlled files; they are rebuilt from the committed
files on OPENSTEP.
