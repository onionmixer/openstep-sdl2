#!/bin/sh
# How long a buffer, at six sounds in the queue.
#   sh snd-buf-ab.sh 62      today: 375 ms latency, 240-280 ms reserve
#   sh snd-buf-ab.sh 100     600 ms latency, 428-468 ms reserve
#
# The stalls are not made rarer by this -- that was measured on the bench,
# and 100 ms stalled as often as 62.  What changes is what a stall costs:
#
#   the reserve absorbs a longer one before the kernel pads with silence
#   the cycle budget is 100 ms rather than 62.5, so a 50 ms stall eats
#   half a cycle instead of four fifths, and a run of them takes much
#   longer to spend the reserve -- which is what "it grates after the
#   first gap" actually is
#
# The price is latency: sound effects lag the picture by a fifth of a
# second more.  water1 can carry that; glquake would not.
ms=$1
if [ -z "$ms" ]; then echo "usage: sh snd-buf-ab.sh <ms>"; exit 2; fi
SDL_OPENSTEP_AUDIO_REPORT=1
SDL_OPENSTEP_MUTEX=block; SDL_OPENSTEP_THREAD_PRIORITY=on
SDL_OPENSTEP_BUFFER_MS=$ms
export SDL_OPENSTEP_AUDIO_REPORT SDL_OPENSTEP_MUTEX SDL_OPENSTEP_THREAD_PRIORITY SDL_OPENSTEP_BUFFER_MS
log=/me/SDL20/log/buf-$ms.log
rm -f $log
echo "buffer_ms=$ms" > $log
cd /me/water1 || exit 1
/usr/local/nxbuild/bin/water1 --data=data >> $log 2>&1
echo "finished -- log is $log"
grep 'frame buffers' $log
grep 'slow submission' $log
grep 'submit ms' $log
