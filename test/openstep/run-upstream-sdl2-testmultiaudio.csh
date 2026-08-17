#!/bin/csh -f
# GCD supplies the OPENSTEP application session; capture the self-terminating
# upstream sample's standard SDL log for later target-side inspection.
cd /tmp/SDL20/bin
exec ./upstream-sdl2-testmultiaudio >& /tmp/SDL20/log/upstream-sdl2-testmultiaudio.log
