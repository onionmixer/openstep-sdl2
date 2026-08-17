# Port notes

- Target: OPENSTEP 4.2 Intel i386/i486.
- Delivery: target-built static `libSDL2.a` and public SDL2 headers.
- Each of the Libraries, Headers and Demos packages includes its own
  target-built i386 Mach-O marker, so its Installer BOM exposes i386 only;
  non-i386 hosts are refused at install.
- Mesa is optional and separate; use it only for `SDL_WINDOW_OPENGL` clients.
- CPU-information APIs are present with a conservative i386 backend: it
  reports one logical CPU and no optional SIMD/CPUID features. This avoids an
  i586 archive member that OPENSTEP's i386 loader cannot load; applications
  must use their scalar code paths unless a future target-safe probe is added.
