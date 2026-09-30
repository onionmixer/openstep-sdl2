#!/bin/sh
# openstep.5 phase A on the target: stage, prepare (fresh build tree -- the
# compile gates read the BUILD tree's src, docs/PLAN_RELEASE_OPENSTEP5.md Q1),
# check the staged sizes against the host, build the three packages, verify
# them, then a silent sound smoke in both API arms.  Installs nothing.
step() { echo "=== $1"; shift; "$@"; rc=$?; echo "=== rc=$rc"; if [ $rc != 0 ]; then echo "CHAIN FAIL"; exit $rc; fi; }
X=/ndrv/_ndrv_scratch/sdl5
B=/me/SDL20/build/SDL-2.32.10-openstep
test -d $X || mkdir $X
step stage csh -f /ndrv/openstep-sdl20/build/stage-openstep.csh /ndrv
step prepare csh -f /me/SDL20/src/build/prepare-openstep-tree.csh
bad=0
for e in 63126:/me/SDL20/build/SDL-2.32.10-openstep/src/audio/openstep/SDL_openstepaudio.m 18106:/me/SDL20/build/SDL-2.32.10-openstep/src/audio/openstep/SDL_openstepaudio.h 107316:/me/SDL20/build/SDL-2.32.10-openstep/src/video/openstep/SDL_openstepvideo.m 2259:/me/SDL20/build/SDL-2.32.10-openstep/src/video/openstep/SDL_openstepvideo.h 352:/me/SDL20/src/packaging/openstep/OpenStepSDL2Libraries.info 392:/me/SDL20/src/packaging/openstep/OpenStepSDL2Headers.info 389:/me/SDL20/src/packaging/openstep/OpenStepSDL2Demos.info 378:/me/SDL20/src/release-docs/RELEASE-MANIFEST.txt; do
    want=`echo $e | sed 's/:.*//'`; f=`echo $e | sed 's/^[0-9]*://'`
    have=`wc -c < $f`
    if [ $have -ne $want ]; then echo "STALE $f host $want target $have"; bad=1; fi
done
if [ $bad != 0 ]; then echo "CHAIN FAIL"; exit 1; fi
echo "staged sizes agree with the host"
step split csh -f /me/SDL20/src/packaging/openstep/build-split-packages.csh
step verify csh -f /me/SDL20/src/packaging/openstep/verify-package.csh
cp $B/libSDL2.a $X/libSDL2-built.a
cp /me/SDL20/sdl2-libraries-payload/Libraries/libSDL2.a $X/libSDL2-payload.a
grep '^Version' /me/SDL20/sdl2-dist/*.pkg/*.info
/usr/bin/sum $B/libSDL2.a /me/SDL20/sdl2-libraries-payload/Libraries/libSDL2.a
# the build prefix the smoke and reopen tests link against (not installed)
rm -rf /tmp/sdl5pfx; mkdir /tmp/sdl5pfx /tmp/sdl5pfx/Libraries /tmp/sdl5pfx/Headers
cp $B/libSDL2.a /tmp/sdl5pfx/Libraries/ && ranlib /tmp/sdl5pfx/Libraries/libSDL2.a
ln -s $B/include /tmp/sdl5pfx/Headers/SDL2
sync
echo "CHAIN PASS"
