#!/bin/csh -f
# Preserve stdout/stderr from the unmodified historical SDL2 GL 1.1 sample.
cd /tmp/SDL20/bin
exec ./upstream-sdl2-2.0.0-testgl2 >& /tmp/SDL20/log/upstream-sdl2-2.0.0-testgl2.log
