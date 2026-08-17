# OPENSTEP SDL2 2.32.10 — openstep.1

First public OPENSTEP 4.2 Intel i486 release of upstream SDL 2.32.10.

## Installer packages

Install all selected packages at the same relocatable prefix, normally
`/LocalDeveloper`.

- `OpenStepSDL2Libraries.pkg` — static `libSDL2.a`.
- `OpenStepSDL2Headers.pkg` — public headers and development documentation.
- `OpenStepSDL2Demos.pkg` — demo source, assets, rebuild scripts and i386
  binaries.

The release archive contains one outer `.pkg.tar.gz` file for each Installer
directory package. Extract it, then open the contained `.pkg` with
OPENSTEP Installer.

## Verification included in this release

- The Libraries archive exposes all 836 required public SDL2 API symbols and
  contains only i386 Mach-O archive members.
- The native package verifier checks split payloads, i386 BOM visibility and
  installation hooks.
- Every Demos payload binary was executed from the installed `/LocalDeveloper`
  prefix; every shipped demo source rebuilt using only that prefix.  See
  [notes/DEMO_PACKAGE_TESTING_20260817.md](notes/DEMO_PACKAGE_TESTING_20260817.md).

## Scope and limitations

- This is an SDL2 port, not an OPENSTEP-specific API extension.
- Standard SDL OpenGL uses the separate OPENSTEP Mesa 3.4.2 Libraries and
  Headers packages at the same prefix.  The compatible `testgl11cube` demo
  targets Mesa's OpenGL 1.2 fixed-function surface.
- CPU-information APIs use the target-safe conservative i386 backend: one
  logical CPU and no optional SIMD/CPUID features.
- OPENSTEP AppKit supplies left and right mouse buttons. Middle-button and
  wheel input are not available on this platform.
