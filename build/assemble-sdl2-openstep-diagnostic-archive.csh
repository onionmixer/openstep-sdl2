#!/bin/csh -f
# Archive the objects already produced by the individual compile gates.
# Keeping this separate from compilation makes a target-side interruption
# observable without rebuilding the full set of objects.

set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep
set archive = $build_root/libSDL2-diagnostic.a
set member_root = $build_root/diagnostic-archive-members
set member_map = $build_root/diagnostic-archive-members.map

set objects = ( $build_root/SDL-init-gate.o $build_root/SDL-assert-gate.o $build_root/core-support-objects/*.o $build_root/common-utility-objects/*.o $build_root/SDL-hidapi-fallback-gate.o $build_root/audio-core-objects/*.o $build_root/openstep-audio-objects/*.o $build_root/events-full-objects/*.o $build_root/sensor-objects/*.o $build_root/joystick-core-objects/*.o $build_root/haptic-core-objects/*.o $build_root/standard-fallback-objects/*.o $build_root/misc-fallback-objects/*.o $build_root/SDL-rect-core-gate.o $build_root/surface-core-objects/*.o $build_root/SDL-bmp-gate.o $build_root/SDL-shape-gate.o $build_root/blit-core-objects/*.o $build_root/libm-objects/*.o $build_root/cpuinfo-objects/*.o $build_root/SDL-video-core-gate.o $build_root/SDL-clipboard-gate.o $build_root/openstep-video-bootstrap-gate.o $build_root/software-renderer-objects/*.o $build_root/SDL-fillrect-gate.o )

# The OPENSTEP ar truncates member names to its historical 15-character
# limit.  Copy objects to unique short names first so distinct objects
# cannot silently collide inside the archive.
rm -rf $member_root
mkdir $member_root
rm -f $member_map
if ($status != 0) exit 1
set member = 0
foreach object ($objects)
    @ member++
    cp $object $member_root/m$member.o
    echo "m$member.o $object" >> $member_map
    if ($status != 0) exit 1
end

rm -f $archive
ar cr $archive $member_root/m*.o
if ($status != 0) exit 1
ranlib $archive
if ($status != 0) exit 1
csh -f /tmp/SDL20/src/build/report-sdl2-openstep-manifest.csh $archive
if ($status != 0) exit 1
echo "assemble-sdl2-openstep-diagnostic-archive: PASS $archive (diagnostic only)"
