#!/bin/sh
# openstep.5: silent sound smoke against the BUILT archive, both API arms.
# SDL_Init pulls the video backend in, so libGL.a is on the line too.
X=/ndrv/_ndrv_scratch/sdl5
B=/me/SDL20/build/SDL-2.32.10-openstep
rm -f $X/sndcost
cc -m486 -O -D__OPENSTEP__ -I$B/include -o $X/sndcost /me/SDL20/src/test/openstep/sndcost.c \
   $B/libSDL2.a /LocalDeveloper/Libraries/libGL.a -lm \
   -framework AppKit -framework Foundation -framework SoundKit || { echo "SMOKE FAIL link"; exit 1; }
SDL_OPENSTEP_AUDIO_REPORT=1; export SDL_OPENSTEP_AUDIO_REPORT
$X/sndcost 44100 12 > $X/smoke-stream.log 2>&1; echo "sndcost stream rc=$?"
SDL_OPENSTEP_AUDIO_API=sound; export SDL_OPENSTEP_AUDIO_API
$X/sndcost 44100 12 > $X/smoke-sound.log 2>&1; echo "sndcost sound rc=$?"
sync
echo "SMOKE DONE"
