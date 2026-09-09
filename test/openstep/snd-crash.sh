#!/bin/sh
# Reproduce the arm-2 crash (yield mutex + priority on) WITH a core file.
#
#   sh /ndrv2/openstep-sdl20/test/openstep/snd-crash.sh
#
# csh's default coredumpsize is 0 (measured), which is why the first
# crash left nothing.  The game is started under a csh that lifts the
# limit; water1 writes `core` in its current directory, /me/water1.
# Play the opening past the typing, then quit from the menu.  If it
# crashes again, the core is at /me/water1/core:
#
#   gdb /usr/local/nxbuild/bin/water1 /me/water1/core
#   (gdb) bt
rm -f /me/water1/core
csh -c 'limit coredumpsize unlimited; sh /usr/local/nxbuild/snd-ab.sh 2 water1'
echo "snd-crash: exit $?"
ls -l /me/water1/core 2>&1
