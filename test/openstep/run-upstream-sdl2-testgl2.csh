#!/bin/csh -f
# Keep GCD's inherited working directory out of the upstream sample's state.
cd /tmp/SDL20/bin
exec ./upstream-sdl2-testgl2
