#!/bin/csh -f
# Combine only actual SDL2/OpenStep objects with ld -r and record the link
# boundary. This diagnostic artifact is neither libSDL2.a nor executable.
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set closure = $build_root/SDL-init-closure-gate.o
set report = $build_root/SDL-init-closure-unresolved.txt

foreach gate (compile-sdl-init-gate.csh compile-sdl-assert-gate.csh compile-sdl-core-support-gate.csh compile-sdl-common-utilities-gate.csh compile-sdl-hidapi-fallback-gate.csh compile-sdl-audio-core-gate.csh compile-openstep-audio-bootstrap-gate.csh compile-sdl-events-full-gate.csh compile-sdl-sensor-gate.csh compile-sdl-joystick-core-gate.csh compile-sdl-haptic-core-gate.csh compile-sdl-standard-fallbacks-gate.csh compile-sdl-misc-fallback-gate.csh compile-sdl-rect-core-gate.csh compile-sdl-surface-core-gate.csh compile-sdl-bmp-gate.csh compile-sdl-shape-gate.csh compile-sdl-blit-core-gate.csh compile-sdl-libm-gate.csh compile-sdl-cpuinfo-gate.csh compile-sdl-video-core-gate.csh compile-sdl-clipboard-gate.csh compile-openstep-video-bootstrap-gate.csh compile-sdl-software-renderer-gate.csh compile-sdl-fillrect-gate.csh)
    csh -f /tmp/SDL20/src/build/$gate
    if ($status != 0) exit 1
end

rm -f $closure $report
ld -r $build_root/SDL-init-gate.o $build_root/SDL-assert-gate.o $build_root/core-support-objects/*.o $build_root/common-utility-objects/*.o $build_root/SDL-hidapi-fallback-gate.o $build_root/audio-core-objects/*.o $build_root/openstep-audio-objects/*.o $build_root/events-full-objects/*.o $build_root/sensor-objects/*.o $build_root/joystick-core-objects/*.o $build_root/haptic-core-objects/*.o $build_root/standard-fallback-objects/*.o $build_root/misc-fallback-objects/*.o $build_root/SDL-rect-core-gate.o $build_root/surface-core-objects/*.o $build_root/SDL-bmp-gate.o $build_root/SDL-shape-gate.o $build_root/blit-core-objects/*.o $build_root/libm-objects/*.o $build_root/cpuinfo-objects/*.o $build_root/SDL-video-core-gate.o $build_root/SDL-clipboard-gate.o $build_root/openstep-video-bootstrap-gate.o $build_root/software-renderer-objects/*.o $build_root/SDL-fillrect-gate.o -o $closure
if ($status != 0) exit 1
nm -u $closure | sort -u > $report
if ($status != 0) exit 1
echo "link-sdl-init-closure-gate: PASS $closure (diagnostic only)"
wc -l $report
