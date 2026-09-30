#!/bin/sh
# E: the pre-release (G5-era) glquake_radeon; F: glquake_sw (stock Mesa, AppKit path).
X=/ndrv/_ndrv_scratch/sdl5
cd /usr/local/quake || exit 1
RDNMesaTime=1; export RDNMesaTime
sleep 5
for t in E:/usr/local/nxbuild/bin/glquake_radeon F:/usr/local/nxbuild/bin/glquake_sw; do
    n=`echo $t | sed 's/:.*//'`; b=`echo $t | sed 's/^.://'`
    rm -f /tmp/glq-self.log
    echo "$n start `date` $b"
    sh /ndrv/openstep-quake/test/run-glquake-self.sh $b 300 110 0 +map start
    cp /tmp/glq-self.log $X/screen-$n.log
    echo "$n end `date`"
    sleep 10
done
sync
echo "EF DONE"
