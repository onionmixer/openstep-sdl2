#!/bin/sh
# openstep.5: put the three packages in /me/packages/sdl2, the synchronous-submit build (fix1)
# in /me/packages/old/sdl2-openstep.4.  Byte-compare every file placed.
P=/me/packages
D=/me/SDL20/sdl2-dist
O=$P/old/sdl2-openstep.5-fix1
fail() { echo "PLACE FAIL $*"; exit 1; }
[ -d $O ] && fail "$O exists"
for n in Libraries Headers Demos; do
    grep '^Version 2.32.10-openstep.5$' $D/OpenStepSDL2$n.pkg/OpenStepSDL2$n.info > /dev/null || fail "$n is not openstep.5"
    grep '^Version 2.32.10-openstep.5$' $P/sdl2/OpenStepSDL2$n.pkg/OpenStepSDL2$n.info > /dev/null || fail "placed $n is not openstep.5 (fix1)"
done
mkdir $O || fail mkdir
for n in Libraries Headers Demos; do
    mv $P/sdl2/OpenStepSDL2$n.pkg $O/ || fail "mv $n"
    cp -r $D/OpenStepSDL2$n.pkg $P/sdl2/ || fail "cp $n"
done
bad=0
for n in Libraries Headers Demos; do
    for f in `ls $D/OpenStepSDL2$n.pkg`; do cmp -s $D/OpenStepSDL2$n.pkg/$f $P/sdl2/OpenStepSDL2$n.pkg/$f || { echo "DIFFERS $n/$f"; bad=1; }; done
    echo "  $n: `grep '^Version' $P/sdl2/OpenStepSDL2$n.pkg/OpenStepSDL2$n.info`"
done
ls $O
( cd $D && tar cf - OpenStepSDL2Libraries.pkg OpenStepSDL2Headers.pkg OpenStepSDL2Demos.pkg ) > /ndrv/_ndrv_scratch/sdl5/sdl2-dist.tar
[ $bad = 0 ] && echo "PLACE PASS" || echo "PLACE FAIL"
