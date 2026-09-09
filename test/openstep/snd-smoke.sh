#!/bin/sh
# Smoke test after a library change, before any game is played by hand.
#
#   sh /ndrv2/openstep-sdl20/test/openstep/snd-smoke.sh
#
# Two things, neither of which needs a person to listen:
#
#   1. sndcost at the device rate and at both game rates.  It plays SILENCE,
#      so nothing is audible; what it proves is that the library still opens,
#      runs and closes a device, that the audio thread still reaches priority
#      18, and what the whole task costs.  The backend's own report comes out
#      of CloseDevice, and it now says WHEN the worst submission was.
#   2. sdlaudioprio in both mutex arms, to show the two arms still differ.
#
# A run is good when every rate reports 356-357 buffers with the gap
# histogram entirely in the first bucket, and the priority line says 18.
B=/me/SDL20/bin
LOG=/me/SDL20/log/smoke.log
rm -f $LOG

for r in 44100 49716 11025; do
    echo "##### sndcost $r #####" >> $LOG
    $B/sndcost $r 12 >> $LOG 2>&1
done

for arm in block yield; do
    echo "##### sdlaudioprio mutex=$arm #####" >> $LOG
    SDL_OPENSTEP_MUTEX=$arm $B/sdlaudioprio 5 >> $LOG 2>&1
done

echo "##### summary #####" >> $LOG
grep "buffers of\|base priority\|SDL mutexes\|refill gap\|all-thread cpu" $LOG >> $LOG
cat $LOG
