#!/bin/sh
# Screen check C: the sdl2quake 1.3 glquake_radeon (SDL2 openstep.4, no
# partial-present change), same harness as A/B.
X=/ndrv/_ndrv_scratch/sdl5
cd /usr/local/quake || exit 1
rm -f /tmp/glq-self.log
RDNMesaTime=1; export RDNMesaTime
sleep 8
echo "C start `date`"
sh /ndrv/openstep-quake/test/run-glquake-self.sh $X/glquake_radeon-1.3 300 110 0 +map start
cp /tmp/glq-self.log $X/screen-C.log; rm -f /tmp/glq-self.log
echo "C end `date`"
sync
echo "C DONE"
