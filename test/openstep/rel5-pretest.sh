#!/bin/sh
# openstep.5 (SoundKit thread) before install: silent smoke, then the
# reopen stress, both linked against the BUILT archive (/tmp/sdl5pfx).
sh /ndrv/openstep-sdl20/test/openstep/rel5-smoke.sh
sh /ndrv/openstep-sdl20/test/openstep/rel5-reopen.sh b2short 500 20 /tmp/sdl5pfx stream
sh /ndrv/openstep-sdl20/test/openstep/rel5-reopen.sh b2long 200 300 /tmp/sdl5pfx "stream sound"
echo "PRETEST DONE"
