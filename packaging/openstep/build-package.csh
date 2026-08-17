#!/bin/csh -f
# Build the native OPENSTEP Installer package from a clean private SDL stage.

set work = /tmp/SDL20
set src = $work/src
set out = $work/build/SDL-2.32.10-openstep
set pay = $work/sdl2-payload
set dst = $work/sdl2-dist
set info = $src/release-packaging/OpenStepSDL2.info
set pre = $src/packaging/openstep/OpenStepSDL2.pre_install
set post = $src/packaging/openstep/OpenStepSDL2.post_install
set marksrc = $src/packaging/openstep/installer-architecture-marker.c
set mark = $pay/Tools/OpenStepSDL2-Intel
set pkgtool = /NextAdmin/Installer.app/package

if (! -x $pkgtool) then
    echo "build-sdl2-package: missing $pkgtool"
    exit 2
endif
if (! -r $info) then
    echo "build-sdl2-package: run stage-openstep.csh first"
    exit 2
endif
if (! -r $pre) then
    echo "build-sdl2-package: missing pre_install"
    exit 2
endif
if (! -r $post) then
    echo "build-sdl2-package: missing post_install"
    exit 2
endif
if (! -r $marksrc) then
    echo "build-sdl2-package: missing architecture marker source"
    exit 2
endif

csh -f $src/build/build-sdl2-openstep-release-archive.csh
if ($status != 0) exit 1
if (! -r $out/libSDL2.a || ! -r $out/include/SDL.h) then
    echo "build-sdl2-package: final archive/header tree missing"
    exit 1
endif

if (-d $pay) rm -rf $pay
if (-d $dst) rm -rf $dst
/bin/mkdirs $pay/Headers/SDL2
/bin/mkdirs $pay/Libraries
/bin/mkdirs $pay/Tools
/bin/mkdirs $pay/Documentation/OpenStep-SDL2-2.32.10
cp $out/include/*.h $pay/Headers/SDL2/
if ($status != 0) exit 1
foreach foreign ( SDL_config_android.h SDL_config_emscripten.h SDL_config_iphoneos.h SDL_config_macosx.h SDL_config_minimal.h SDL_config_ngage.h SDL_config_os2.h SDL_config_pandora.h SDL_config_windows.h SDL_config_wingdk.h SDL_config_winrt.h SDL_config_xbox.h )
    rm -f $pay/Headers/SDL2/$foreign
end
cp $out/libSDL2.a $pay/Libraries/
cc -m486 -o $mark $marksrc
if ($status != 0) exit 1
chmod 555 $mark
cp $src/release-docs/README.OPENSTEP $pay/Documentation/OpenStep-SDL2-2.32.10/
cp $src/release-docs/API-COVERAGE.md $pay/Documentation/OpenStep-SDL2-2.32.10/
cp $src/release-docs/PORT-NOTES.md $pay/Documentation/OpenStep-SDL2-2.32.10/
cp $src/release-docs/LINKING.md $pay/Documentation/OpenStep-SDL2-2.32.10/
cp $src/upstream/SDL-2.32.10/LICENSE.txt $pay/Documentation/OpenStep-SDL2-2.32.10/LICENSE.txt
cp $src/release-docs/RELEASE-MANIFEST.txt $pay/Documentation/OpenStep-SDL2-2.32.10/
if ($status != 0) exit 1

/bin/mkdirs $dst
$pkgtool $pay $info -d $dst
if ($status != 0) exit 1
if (! -d $dst/OpenStepSDL2.pkg) then
    echo "build-sdl2-package: package output missing"
    exit 1
endif
cp $pre $dst/OpenStepSDL2.pkg/OpenStepSDL2.pre_install
cp $post $dst/OpenStepSDL2.pkg/OpenStepSDL2.post_install
chmod 555 $dst/OpenStepSDL2.pkg/OpenStepSDL2.pre_install $dst/OpenStepSDL2.pkg/OpenStepSDL2.post_install
if ($status != 0) exit 1
echo "build-sdl2-package: PASS $dst/OpenStepSDL2.pkg"
