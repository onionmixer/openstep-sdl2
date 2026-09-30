#!/bin/sh
# Screen check D after the reboot: the installed (final) glquake_radeon,
# kernel recovery count before and after.
X=/ndrv/_ndrv_scratch/sdl5
cd /usr/local/quake || exit 1
rm -f /tmp/glq-self.log
echo "recovers before: `grep 'recover=[0-9]' /usr/adm/messages | tail -1`"
grep 'RDN-R5 autostart' /usr/adm/messages | tail -1
RDNMesaTime=1; export RDNMesaTime
SDL_OPENSTEP_AUDIO_REPORT=1; export SDL_OPENSTEP_AUDIO_REPORT
sleep 5
echo "D start `date`"
sh /ndrv/openstep-quake/test/run-glquake-self.sh /usr/local/quake/glquake_radeon 300 110 0 +map start
cp /tmp/glq-self.log $X/screen-D.log; rm -f /tmp/glq-self.log
echo "D end `date`"
echo "recovers after: `grep 'recover=[0-9]' /usr/adm/messages | tail -1`"
sync
echo "D DONE"
