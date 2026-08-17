#!/bin/csh -f
# GCD preserves its server working directory.  The unmodified upstream sample
# falls back to its process CWD for icon.bmp when OPENSTEP's standard
# SDL_GetBasePath() fallback reports unsupported, so start it beside its asset.
cd /tmp/SDL20/bin
exec ./upstream-sdl2-testspriteminimal
