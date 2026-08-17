# OPENSTEP SDK split-package contract

Each product is delivered as three independently installable OPENSTEP Installer
packages: runtime/library, development headers and demos. They share the
relocatable default prefix `/LocalDeveloper`.

| Product | Library package | Headers package | Demos package |
| --- | --- | --- |
| SDL 2.32.10 | `OpenStepSDL2Libraries.pkg` | `OpenStepSDL2Headers.pkg` | `OpenStepSDL2Demos.pkg` |
| Mesa 3.4.2 | `OpenStepMesa342Libraries.pkg` | `OpenStepMesa342Headers.pkg` | `OpenStepMesa342Demos.pkg` |

## Library packages

- Contain only static archives and the tiny i386 Mach-O Installer marker.
- SDL: `Libraries/libSDL2.a`.
- Mesa: `Libraries/libGL.a` and `Libraries/libGLU.a`.
- Are i386/i486-only: their BOM exposes the marker for i386 only and their
  `pre_install` hook rejects a non-i386 machine.
- Run `post_install` to rerun `ranlib` after extraction, because OPENSTEP's
  archive index records the pre-install pathname.

## Headers packages

- Contain only public headers, licenses and port/linking documentation.
- Do not duplicate product archives or executable demos.
- Carry a tiny i386 Mach-O Installer marker and i386 `pre_install` policy.

## Demos packages

- Contain no headers or product archives. Every demo includes its source,
  target build script and a target-built i386 executable.
- SDL includes the port smoke plus upstream `testgl2`, `testspriteminimal`,
  `testmultiaudio`, `testthread` and `testtimer` consumers.
- Mesa includes the OSMesa example and the original OPENSTEP MesaView source,
  nib resources and executable.
- Each demo build script accepts an optional installation prefix. It requires
  the product Libraries and Headers packages at that prefix; SDL demos that
  link OpenGL additionally require Mesa Libraries.

## Installation and test order

1. Install the product's `Libraries` package at a selected prefix.
2. Install its `Headers` package at the identical prefix.
3. Optionally install its `Demos` package at that prefix.
4. Build a source demo from `Examples/` with that prefix.
5. SDL OpenGL demos additionally require Mesa Libraries at that prefix.

Library and Headers packages have separate receipts and deletion scopes.  No
package may install the other package's files.

## Source-control rule

Every release commit includes the package `.info` metadata, build and verify
scripts, Installer hooks, architecture-marker source, demo source and demo
build scripts. Target-built `.pkg` directories and `/tmp` stages are release
artifacts, not source-controlled files; they are rebuilt from the committed
files on OPENSTEP.
