#!/bin/sh
# Measurement build (docs/PLAN_RELEASE_OPENSTEP5.md 16): glquake_radeon linked
# against the BUILT (traced) libSDL2.a, not installed; N runs with the trace on.
X=/ndrv/_ndrv_scratch/sdl5
T=$X/tr
N=${1:-30}
P=/tmp/_qtpfx
O=/tmp/_qtout
Q=/ndrv/openstep-quake
B=/me/SDL20/build/SDL-2.32.10-openstep
rm -rf $P $O; mkdir $P $P/Libraries $O $O/bin
cp $B/libSDL2.a /LocalDeveloper/Libraries/libGL.a $P/Libraries/
cp /ndrv/openstep-matrox-remade/build/mesa/libGL_mga.a $P/Libraries/
ranlib $P/Libraries/libSDL2.a $P/Libraries/libGL.a $P/Libraries/libGL_mga.a
ln -s /LocalDeveloper/Headers $P/Headers
ACCEL=radeon; RDN_LIB=/ndrv/openstep-radeon9250/build/m1b/790662776/libGL_radeon.a; export ACCEL RDN_LIB
sh $Q/build/build-glquake.sh $Q $P /ndrv/openstep-matrox-remade $O > $X/trace-build.log 2>&1 || { echo "TRACE FAIL build"; exit 1; }
n=`/bin/strings $O/bin/glquake_radeon | grep OPENSTEP_TRACE_ROWS | wc -l`
m=`/bin/strings $O/bin/glquake_radeon | grep 'stream trace 1' | wc -l`
echo "traced build: trace header string $m"
[ "$m" -ge 1 ] || { echo "TRACE FAIL not the traced library"; exit 1; }
test -d $T || mkdir $T
SDL_OPENSTEP_AUDIO_REPORT=1; export SDL_OPENSTEP_AUDIO_REPORT
SDL_OPENSTEP_AUDIO_TRACE=$T/glq; export SDL_OPENSTEP_AUDIO_TRACE
cd /usr/local/quake || exit 1
i=0
while [ $i -lt $N ]; do
    i=`expr $i + 1`
    out=`sh $Q/test/run-glquake-self.sh $O/bin/glquake_radeon 300 110 0 +map start 2>&1`
    ticks=`grep 'mgastats tick' /tmp/glq-self.log | wc -l`
    echo "trace run $i: $out ticks=$ticks"
    cp /tmp/glq-self.log $X/tr/run-$i.log
done
sync
echo "TRACE DONE"
