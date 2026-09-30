#!/bin/sh
# Reopen stress against an SDL2 prefix (default: the installed one).
#   rel5-reopen.sh <tag> <cycles> <maxms> [prefix]
X=/ndrv/_ndrv_scratch/sdl5
TAG=$1; C=$2; M=$3; P=${4:-/LocalDeveloper}; ARMS=${5:-"stream sound"}
cd /tmp || exit 1
rm -f /tmp/sndreopen-$TAG /tmp/core
cc -m486 -O -D__OPENSTEP__ -I$P/Headers/SDL2 -I$P/Headers -o /tmp/sndreopen-$TAG /ndrv/openstep-sdl20/test/openstep/sndreopen.c \
   $P/Libraries/libSDL2.a /LocalDeveloper/Libraries/libGL.a -lm \
   -framework AppKit -framework Foundation -framework SoundKit > /tmp/sndreopen-cc.log 2>&1 || { cat /tmp/sndreopen-cc.log; echo "REOPEN FAIL link"; exit 1; }
SDL_OPENSTEP_AUDIO_REPORT=1; export SDL_OPENSTEP_AUDIO_REPORT
for arm in $ARMS; do
    SDL_OPENSTEP_AUDIO_API=$arm; export SDL_OPENSTEP_AUDIO_API
    csh -f -c "limit coredumpsize unlimited; exec /tmp/sndreopen-$TAG $C $M 7" > $X/reopen-$TAG-$arm.log 2>&1
    rc=$?
    echo "$TAG $arm rc=$rc last: `tail -1 $X/reopen-$TAG-$arm.log`"
    if [ -r /tmp/core ]; then mv /tmp/core $X/core-reopen-$TAG-$arm; echo "  core saved"; fi
done
sync
echo "REOPEN DONE"
