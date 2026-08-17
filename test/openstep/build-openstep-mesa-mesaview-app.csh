#!/bin/csh -f
# Build Mesa 3.4.2's original OpenStep/MesaView application in a private app
# bundle.  It is linked but not run here: launch it from a console Workspace
# terminal to test the target's AppKit/DPS session independently of SDL.
set mesa = /tmp/SDL20/mesa/Mesa-3.4.2
set view = $mesa/OpenStep/MesaView
set app = /tmp/SDL20/bin/MesaView.app
set executable = $app/MesaView
set resources = $app/Resources
set info = $resources/Info-nextstep.plist

if (! -r $mesa/lib/libGL.a || ! -r $mesa/lib/libGLU.a || ! -r $view/MesaView.m || ! -d $view/English.lproj) then
    echo "build-openstep-mesa-mesaview-app: build and stage Mesa first"
    exit 2
endif

if (! -d $app) mkdir $app
if (! -d $resources) mkdir $resources
if (! -d $resources/English.lproj) mkdir $resources/English.lproj
# ProjectBuilder generates this file from PB.project.  AppKit reads it from
# Resources (not from the app root) to discover NSApplication and MesaView.nib.
/usr/lib/mergeInfo $view/PB.project -o $info
if ($status != 0) exit 1
cp -R $view/English.lproj/MesaView.nib $resources/English.lproj/
if ($status != 0) exit 1
rm -f $executable
cc -m486 -O -Wall -I$mesa/include -I$view $view/MesaView_main.m $view/MesaView.m $view/mesadraw.c $view/vect3d.c -L$mesa/lib -lGLU -lGL -lm -framework AppKit -framework Foundation -o $executable
if ($status != 0) exit 1
csh -f /tmp/SDL20/src/port/openstep/fix-macho-i486-subtype.csh $executable
if ($status != 0) exit 1
echo "build-openstep-mesa-mesaview-app: PASS $app (not run)"
