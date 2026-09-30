#!/bin/sh
# Screen A/B for the installed glquake_radeon (docs/PLAN_RELEASE_OPENSTEP5.md 21).
#   A: default audio (stream, the SoundKit NSThread is detached)
#   B: SDL_OPENSTEP_AUDIO_API=sound (per-sound; no NSThread is ever detached)
# Both with the radeon library's present counters (RDN-P) on; a person
# watches the screen and says which run changed on screen.
X=/ndrv/_ndrv_scratch/sdl5
cd /usr/local/quake || exit 1
rm -f /tmp/glq-self.log
RDNMesaTime=1; export RDNMesaTime
SDL_OPENSTEP_AUDIO_REPORT=1; export SDL_OPENSTEP_AUDIO_REPORT
echo "A start `date`"
sh /ndrv/openstep-quake/test/run-glquake-self.sh /usr/local/quake/glquake_radeon 300 110 0 +map start
cp /tmp/glq-self.log $X/screen-A.log; rm -f /tmp/glq-self.log
echo "A end `date`"
sleep 10
SDL_OPENSTEP_AUDIO_API=sound; export SDL_OPENSTEP_AUDIO_API
echo "B start `date`"
sh /ndrv/openstep-quake/test/run-glquake-self.sh /usr/local/quake/glquake_radeon 300 110 0 +map start
cp /tmp/glq-self.log $X/screen-B.log; rm -f /tmp/glq-self.log
echo "B end `date`"
sync
echo "AB DONE"
