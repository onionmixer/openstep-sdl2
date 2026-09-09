#!/bin/sh
# One water1 run with the backend's two diagnostic switches.
#
#   sh snd-ahead.sh <ahead 2..7> <helper 0|1>
#
#   ahead    SDL_OPENSTEP_QUEUE_AHEAD: how many sounds to keep in flight.
#            6 is the shipped default and is exactly libsound's limit on
#            concurrently started sounds; 5 steps off that boundary at the
#            cost of one buffer of reserve.
#   helper   SDL_OPENSTEP_HELPER_PRIORITY: raise this task's base-priority-0
#            threads once, after the first submission.
#
# LEAVE helper AT 0.  It was measured on the bench (sndslack mode 4) and it
# made things much worse -- 986 ms inside SNDStartPlaying.  The switch is
# kept because the measurement is worth being able to repeat, not because
# the answer is in doubt.
#
# Play the same scene each time and QUIT FROM THE MENU: the report is
# printed when the audio device closes, and a killed process never closes
# it.  The log is named for the arm so runs do not overwrite each other.
a=$1
h=$2
if [ -z "$a" ] || [ -z "$h" ]; then
    echo "usage: sh snd-ahead.sh <ahead 2..7> <helper 0|1>"
    exit 2
fi
SDL_OPENSTEP_AUDIO_REPORT=1
SDL_OPENSTEP_MUTEX=block
SDL_OPENSTEP_THREAD_PRIORITY=on
SDL_OPENSTEP_QUEUE_AHEAD=$a
SDL_OPENSTEP_HELPER_PRIORITY=$h
export SDL_OPENSTEP_AUDIO_REPORT SDL_OPENSTEP_MUTEX SDL_OPENSTEP_THREAD_PRIORITY
export SDL_OPENSTEP_QUEUE_AHEAD SDL_OPENSTEP_HELPER_PRIORITY
log=/me/SDL20/log/ahead-$a-$h.log
rm -f $log
echo "ahead=$a helper=$h" > $log
cd /me/water1 || exit 1
/usr/local/nxbuild/bin/water1 --data=data >> $log 2>&1
echo "finished -- log is $log"
grep 'OPENSTEP audio' $log
