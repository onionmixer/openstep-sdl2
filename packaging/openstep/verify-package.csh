#!/bin/csh -f
# Verify the two independently installable SDL2 release packages without
# installing either one.  This is the release gate for the split layout.
set work = /tmp/SDL20
set src = $work/src
set dist = $work/sdl2-dist
set libraries = $dist/OpenStepSDL2Libraries.pkg
set headers = $dist/OpenStepSDL2Headers.pkg
set lunpack = $work/sdl2-libraries-package-verify
set hunpack = $work/sdl2-headers-package-verify
set installer_tar = /NextAdmin/Installer.app/installer_tar

foreach file ( $libraries/OpenStepSDL2Libraries.tar.Z $libraries/OpenStepSDL2Libraries.bom $libraries/OpenStepSDL2Libraries.info $libraries/OpenStepSDL2Libraries.pre_install $libraries/OpenStepSDL2Libraries.post_install $headers/OpenStepSDL2Headers.tar.Z $headers/OpenStepSDL2Headers.bom $headers/OpenStepSDL2Headers.info $headers/OpenStepSDL2Headers.pre_install )
    if (! -r $file) then
        echo "verify-sdl2-package: missing $file"
        exit 2
    endif
end

if (-d $lunpack) rm -rf $lunpack
if (-d $hunpack) rm -rf $hunpack
mkdir $lunpack
mkdir $hunpack
(cd $lunpack; /usr/ucb/zcat $libraries/OpenStepSDL2Libraries.tar.Z | $installer_tar xf -)
if ($status != 0) exit 1
(cd $hunpack; /usr/ucb/zcat $headers/OpenStepSDL2Headers.tar.Z | $installer_tar xf -)
if ($status != 0) exit 1

if (! -r $lunpack/Libraries/libSDL2.a || ! -r $lunpack/Tools/OpenStepSDL2-Intel) then
    echo "verify-sdl2-package: Libraries payload is incomplete"
    exit 1
endif
if (! -r $hunpack/Headers/SDL2/SDL.h || ! -r $hunpack/Headers/SDL2/SDL_config_openstep.h || ! -r $hunpack/Examples/OpenStep-SDL2-2.32.10/sdl2_clear.c || ! -r $hunpack/Examples/OpenStep-SDL2-2.32.10/build-sdl2-clear.csh || ! -r $hunpack/Examples/OpenStep-SDL2-2.32.10/sdl2_clear || ! -r $hunpack/Tools/OpenStepSDL2Headers-Intel) then
    echo "verify-sdl2-package: Headers/Examples payload is incomplete"
    exit 1
endif
if (-e $lunpack/Headers || -e $hunpack/Libraries/libSDL2.a) then
    echo "verify-sdl2-package: package payloads are not separated"
    exit 1
endif

csh -f $src/build/check-final-api-manifest.csh $lunpack/Libraries/libSDL2.a
if ($status != 0) exit 1
csh -f $src/test/openstep/check-sdl2-archive-cpu.csh $lunpack/Libraries/libSDL2.a
if ($status != 0) exit 1
file $lunpack/Tools/OpenStepSDL2-Intel | grep i386 > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: library marker is not i386 Mach-O"
    exit 1
endif
file $hunpack/Examples/OpenStep-SDL2-2.32.10/sdl2_clear | grep i386 > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: shipped example is not i386 Mach-O"
    exit 1
endif
file $hunpack/Tools/OpenStepSDL2Headers-Intel | grep i386 > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: Headers marker is not i386 Mach-O"
    exit 1
endif

/usr/etc/lsbom -arch i386 -s $libraries/OpenStepSDL2Libraries.bom | grep OpenStepSDL2-Intel > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: library i386 BOM marker missing"
    exit 1
endif
/usr/etc/lsbom -arch m68k -s $libraries/OpenStepSDL2Libraries.bom | grep OpenStepSDL2-Intel > /dev/null
if ($status == 0) then
    echo "verify-sdl2-package: library Intel marker leaked into m68k BOM"
    exit 1
endif
/usr/etc/lsbom -arch i386 -s $headers/OpenStepSDL2Headers.bom | grep OpenStepSDL2Headers-Intel > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: Headers i386 BOM marker missing"
    exit 1
endif
/usr/etc/lsbom -arch m68k -s $headers/OpenStepSDL2Headers.bom | grep OpenStepSDL2Headers-Intel > /dev/null
if ($status == 0) then
    echo "verify-sdl2-package: Headers Intel marker leaked into m68k BOM"
    exit 1
endif

ls -l $libraries/OpenStepSDL2Libraries.pre_install $libraries/OpenStepSDL2Libraries.post_install $headers/OpenStepSDL2Headers.pre_install | grep 'r.xr.xr.x' > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: Installer hooks are not executable"
    exit 1
endif
echo "verify-sdl2-package: PASS split payloads, 836 API archive, i386 BOM and hooks"
