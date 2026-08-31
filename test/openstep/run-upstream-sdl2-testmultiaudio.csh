#!/bin/csh -f
# GCD supplies the OPENSTEP application session; capture the self-terminating
# upstream sample's standard SDL log for later target-side inspection.
cd /me/SDL20/bin
exec ./upstream-sdl2-testmultiaudio >& /me/SDL20/log/upstream-sdl2-testmultiaudio.log
