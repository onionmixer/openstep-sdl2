#!/bin/csh -f
# Assemble all currently compiler-gated real SDL/OpenStep objects into one
# static archive. It is intentionally NOT named libSDL2.a: only the final
# manifest gate may create a release archive with that name.

set toolbin = /tmp/SDL20/i386-compiler
if (-d $toolbin) rm -rf $toolbin
mkdir $toolbin
cp /tmp/SDL20/src/build/cc-i386-wrapper.csh $toolbin/cc
chmod 555 $toolbin/cc
setenv PATH ${toolbin}:$PATH
rehash

foreach gate (compile-sdl-init-gate.csh compile-sdl-assert-gate.csh compile-sdl-core-support-gate.csh compile-sdl-common-utilities-gate.csh compile-sdl-hidapi-fallback-gate.csh compile-sdl-audio-core-gate.csh compile-openstep-audio-bootstrap-gate.csh compile-sdl-events-full-gate.csh compile-sdl-sensor-gate.csh compile-sdl-joystick-core-gate.csh compile-sdl-haptic-core-gate.csh compile-sdl-standard-fallbacks-gate.csh compile-sdl-misc-fallback-gate.csh compile-sdl-rect-core-gate.csh compile-sdl-surface-core-gate.csh compile-sdl-bmp-gate.csh compile-sdl-shape-gate.csh compile-sdl-blit-core-gate.csh compile-sdl-libm-gate.csh compile-sdl-cpuinfo-gate.csh compile-sdl-video-core-gate.csh compile-sdl-clipboard-gate.csh compile-openstep-video-bootstrap-gate.csh compile-sdl-software-renderer-gate.csh compile-sdl-fillrect-gate.csh)
    csh -f /tmp/SDL20/src/build/$gate
    if ($status != 0) exit 1
end

# Delegate archive creation to the short-member assembler.  OPENSTEP ar
# truncates ordinary object basenames and would otherwise invalidate the
# release API-manifest gate.
csh -f /tmp/SDL20/src/build/assemble-sdl2-openstep-diagnostic-archive.csh
if ($status != 0) exit 1
echo "build-sdl2-openstep-diagnostic-archive: PASS short-member diagnostic archive"
