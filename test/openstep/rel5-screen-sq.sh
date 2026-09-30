#!/bin/sh
# squake (software surface, SDL2 openstep.5 partial-present change) on screen, ~30 s.
X=/ndrv/_ndrv_scratch/sdl5
cd /usr/local/quake || exit 1
sleep 10
echo "SQ start `date`"
./squake -basedir /usr/local/quake -width 640 -height 480 +map start > $X/screen-SQ.log 2>&1 &
sleep 30
p=`ps -ax | awk '/[s]quake -basedir/ {print $1}'`
[ -n "$p" ] && kill $p
sleep 3
p=`ps -ax | awk '/[s]quake -basedir/ {print $1}'`
[ -n "$p" ] && kill -9 $p
echo "SQ end `date`"
sync
echo "SQ DONE"
