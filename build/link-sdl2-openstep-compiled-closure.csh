#!/bin/csh -f
# Link the objects produced by individual compile gates without rebuilding
# them. This is the target-side link phase used when remote sessions are
# intentionally kept short and observable.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set closure = $build_root/SDL-init-closure-gate.o
set report = $build_root/SDL-init-closure-unresolved.txt

set objects = ( $build_root/SDL-init-gate.o $build_root/SDL-assert-gate.o $build_root/core-support-objects/*.o $build_root/common-utility-objects/*.o $build_root/SDL-hidapi-fallback-gate.o $build_root/audio-core-objects/*.o $build_root/openstep-audio-objects/*.o $build_root/events-full-objects/*.o $build_root/sensor-objects/*.o $build_root/joystick-core-objects/*.o $build_root/haptic-core-objects/*.o $build_root/standard-fallback-objects/*.o $build_root/misc-fallback-objects/*.o $build_root/SDL-rect-core-gate.o $build_root/surface-core-objects/*.o $build_root/SDL-bmp-gate.o $build_root/SDL-shape-gate.o $build_root/blit-core-objects/*.o $build_root/libm-objects/*.o $build_root/cpuinfo-objects/*.o $build_root/SDL-video-core-gate.o $build_root/SDL-clipboard-gate.o $build_root/openstep-video-bootstrap-gate.o $build_root/software-renderer-objects/*.o $build_root/SDL-fillrect-gate.o )

rm -f $closure $report
ld -r $objects -o $closure
if ($status != 0) exit 1
nm -u $closure | sort -u > $report
if ($status != 0) exit 1
echo "link-sdl2-openstep-compiled-closure: PASS $closure (diagnostic only)"
wc -l $report
