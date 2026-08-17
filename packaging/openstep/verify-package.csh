#!/bin/csh -f
# Verify SDL2 Libraries, Headers and Demos packages without installing them.
set work = /tmp/SDL20
set src = $work/src
set dist = $work/sdl2-dist
set libraries = $dist/OpenStepSDL2Libraries.pkg
set headers = $dist/OpenStepSDL2Headers.pkg
set demos = $dist/OpenStepSDL2Demos.pkg
set lunpack = $work/sdl2-libraries-package-verify
set hunpack = $work/sdl2-headers-package-verify
set dunpack = $work/sdl2-demos-package-verify
set installer_tar = /NextAdmin/Installer.app/installer_tar

foreach file ( $libraries/OpenStepSDL2Libraries.tar.Z $libraries/OpenStepSDL2Libraries.bom $libraries/OpenStepSDL2Libraries.info $libraries/OpenStepSDL2Libraries.pre_install $libraries/OpenStepSDL2Libraries.post_install $headers/OpenStepSDL2Headers.tar.Z $headers/OpenStepSDL2Headers.bom $headers/OpenStepSDL2Headers.info $headers/OpenStepSDL2Headers.pre_install $demos/OpenStepSDL2Demos.tar.Z $demos/OpenStepSDL2Demos.bom $demos/OpenStepSDL2Demos.info $demos/OpenStepSDL2Demos.pre_install )
    if (! -r $file) then
        echo "verify-sdl2-package: missing $file"
        exit 2
    endif
end
foreach directory ( $lunpack $hunpack $dunpack )
    if (-d $directory) rm -rf $directory
    mkdir $directory
end
(cd $lunpack; /usr/ucb/zcat $libraries/OpenStepSDL2Libraries.tar.Z | $installer_tar xf -)
if ($status != 0) exit 1
(cd $hunpack; /usr/ucb/zcat $headers/OpenStepSDL2Headers.tar.Z | $installer_tar xf -)
if ($status != 0) exit 1
(cd $dunpack; /usr/ucb/zcat $demos/OpenStepSDL2Demos.tar.Z | $installer_tar xf -)
if ($status != 0) exit 1

if (! -r $lunpack/Libraries/libSDL2.a || ! -r $lunpack/Tools/OpenStepSDL2-Intel) then
    echo "verify-sdl2-package: Libraries payload is incomplete"
    exit 1
endif
if (! -r $hunpack/Headers/SDL2/SDL.h || ! -r $hunpack/Headers/SDL2/SDL_config_openstep.h || ! -r $hunpack/Documentation/OpenStep-SDL2-2.32.10/README.OPENSTEP || ! -r $hunpack/Tools/OpenStepSDL2Headers-Intel) then
    echo "verify-sdl2-package: Headers payload is incomplete"
    exit 1
endif
if (! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/sdl2_clear.c || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/build-sdl2-clear.csh || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/build-upstream-demos.csh || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/testgl11cube || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/testspriteminimal || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/testmultiaudio || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/testthread || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/testtimer || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/icon.bmp || ! -r $dunpack/Examples/OpenStep-SDL2-2.32.10/sample.wav || ! -r $dunpack/Tools/OpenStepSDL2Demos-Intel) then
    echo "verify-sdl2-package: Demos payload is incomplete"
    exit 1
endif
if (-e $lunpack/Headers || -e $lunpack/Examples || -e $hunpack/Libraries || -e $hunpack/Examples || -e $dunpack/Libraries || -e $dunpack/Headers) then
    echo "verify-sdl2-package: payloads are not separated"
    exit 1
endif
csh -f $src/build/check-final-api-manifest.csh $lunpack/Libraries/libSDL2.a
if ($status != 0) exit 1
csh -f $src/test/openstep/check-sdl2-archive-cpu.csh $lunpack/Libraries/libSDL2.a
if ($status != 0) exit 1
foreach binary ( $lunpack/Tools/OpenStepSDL2-Intel $hunpack/Tools/OpenStepSDL2Headers-Intel $dunpack/Tools/OpenStepSDL2Demos-Intel $dunpack/Examples/OpenStep-SDL2-2.32.10/sdl2_clear $dunpack/Examples/OpenStep-SDL2-2.32.10/testgl11cube $dunpack/Examples/OpenStep-SDL2-2.32.10/testspriteminimal $dunpack/Examples/OpenStep-SDL2-2.32.10/testmultiaudio $dunpack/Examples/OpenStep-SDL2-2.32.10/testthread $dunpack/Examples/OpenStep-SDL2-2.32.10/testtimer )
    file $binary | grep i386 > /dev/null
    if ($status != 0) then
        echo "verify-sdl2-package: non-i386 binary $binary"
        exit 1
    endif
end
foreach name ( Libraries Headers Demos )
    if ("$name" == "Libraries") then
        set marker = OpenStepSDL2-Intel
    else
        set marker = OpenStepSDL2$name-Intel
    endif
    set package = $dist/OpenStepSDL2$name.pkg
    /usr/etc/lsbom -arch i386 -s $package/OpenStepSDL2$name.bom | grep $marker > /dev/null
    if ($status != 0) then
        echo "verify-sdl2-package: $name i386 BOM marker missing"
        exit 1
    endif
    /usr/etc/lsbom -arch m68k -s $package/OpenStepSDL2$name.bom | grep $marker > /dev/null
    if ($status == 0) then
        echo "verify-sdl2-package: $name marker leaked into m68k BOM"
        exit 1
    endif
end
ls -l $libraries/OpenStepSDL2Libraries.pre_install $libraries/OpenStepSDL2Libraries.post_install $headers/OpenStepSDL2Headers.pre_install $demos/OpenStepSDL2Demos.pre_install | grep 'r.xr.xr.x' > /dev/null
if ($status != 0) then
    echo "verify-sdl2-package: Installer hooks are not executable"
    exit 1
endif
echo "verify-sdl2-package: PASS separated payloads, 836 API archive, i386 BOM and hooks"
