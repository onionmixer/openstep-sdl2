# Port notes

- Target: OPENSTEP 4.2 Intel i386/i486.
- Delivery: target-built static `libSDL2.a` and public SDL2 headers.
- Both packages include target-built i386 Mach-O executables (the library
  package marker and the headers package demo), so their Installer BOMs expose
  i386 only; non-i386 hosts are refused at install.
- Mesa is optional and separate; use it only for `SDL_WINDOW_OPENGL` clients.
- CPU-information APIs are present with a conservative i386 backend: it
  reports one logical CPU and no optional SIMD/CPUID features. This avoids an
  i586 archive member that OPENSTEP's i386 loader cannot load; applications
  must use their scalar code paths unless a future target-safe probe is added.
