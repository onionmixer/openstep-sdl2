#!/bin/sh
# G: the scissor hypothesis -- one radeon teapot (it clears on the card, and the
# clear writes DEFAULT_SC_BOTTOM_RIGHT), then the same installed glquake_radeon.
X=/ndrv/_ndrv_scratch/sdl5
T=/usr/local/rel1/build-b78/_rdnteapot/overlay/Examples/Mesa342/RDNTeapot/rdnteapot_hybrid
rm -rf /tmp/_g; mkdir /tmp/_g; cd /tmp/_g || exit 1
echo "teapot `date`"
RDNMesaTime=1 $T 64 64 10 card.ppm 2>&1 | egrep 'RDN-C|clear|step=end' | head -5
sleep 5
cd /usr/local/quake || exit 1
rm -f /tmp/glq-self.log
RDNMesaTime=1; export RDNMesaTime
echo "G start `date`"
sh /ndrv/openstep-quake/test/run-glquake-self.sh /usr/local/quake/glquake_radeon 300 110 0 +map start
cp /tmp/glq-self.log $X/screen-G.log; rm -f /tmp/glq-self.log
echo "G end `date`"
sync
echo "G DONE"
