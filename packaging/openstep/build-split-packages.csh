#!/bin/csh -f
# Produce independently installable SDL2 Libraries, Headers and Demos packages.
set work = /tmp/SDL20
set src = $work/src
set out = $work/build/SDL-2.32.10-openstep
set lpay = $work/sdl2-libraries-payload
set hpay = $work/sdl2-headers-payload
set dpay = $work/sdl2-demos-payload
set dst = $work/sdl2-dist
set linf = $src/packaging/openstep/OpenStepSDL2Libraries.info
set hinf = $src/packaging/openstep/OpenStepSDL2Headers.info
set dinf = $src/packaging/openstep/OpenStepSDL2Demos.info
set pre = $src/packaging/openstep/OpenStepSDL2.pre_install
set hpre = $src/packaging/openstep/OpenStepSDL2Headers.pre_install
set dpre = $src/packaging/openstep/OpenStepSDL2Demos.pre_install
set post = $src/packaging/openstep/OpenStepSDL2.post_install
set marksrc = $src/packaging/openstep/installer-architecture-marker.c
set pkgtool = /NextAdmin/Installer.app/package

foreach file ( $linf $hinf $dinf $pre $hpre $dpre $post $marksrc )
    if (! -r $file) then
        echo "build-sdl2-split: run stage-openstep.csh first"
        exit 2
    endif
end
csh -f $src/build/build-sdl2-openstep-release-archive.csh
if ($status != 0) exit 1
if (! -r $out/libSDL2.a || ! -r $out/include/SDL.h) exit 1
csh -f $src/test/openstep/check-sdl2-archive-cpu.csh $out/libSDL2.a
if ($status != 0) then
    echo "build-sdl2-split: refusing archive with a non-i386 member"
    exit 1
endif
if (-d $lpay) rm -rf $lpay
if (-d $hpay) rm -rf $hpay
if (-d $dpay) rm -rf $dpay
if (-d $dst) rm -rf $dst

/bin/mkdirs $lpay/Libraries
/bin/mkdirs $lpay/Tools
cp $out/libSDL2.a $lpay/Libraries/
cc -m486 -o $lpay/Tools/OpenStepSDL2-Intel $marksrc
if ($status != 0) exit 1
chmod 555 $lpay/Tools/OpenStepSDL2-Intel

/bin/mkdirs $hpay/Headers/SDL2
/bin/mkdirs $hpay/Documentation/OpenStep-SDL2-2.32.10
/bin/mkdirs $hpay/Tools
cc -m486 -o $hpay/Tools/OpenStepSDL2Headers-Intel $marksrc
if ($status != 0) exit 1
chmod 555 $hpay/Tools/OpenStepSDL2Headers-Intel
cp $out/include/*.h $hpay/Headers/SDL2/
foreach foreign ( SDL_config_android.h SDL_config_emscripten.h SDL_config_iphoneos.h SDL_config_macosx.h SDL_config_minimal.h SDL_config_ngage.h SDL_config_os2.h SDL_config_pandora.h SDL_config_windows.h SDL_config_wingdk.h SDL_config_winrt.h SDL_config_xbox.h )
    rm -f $hpay/Headers/SDL2/$foreign
end
cp $src/release-docs/* $hpay/Documentation/OpenStep-SDL2-2.32.10/
cp $src/upstream/SDL-2.32.10/LICENSE.txt $hpay/Documentation/OpenStep-SDL2-2.32.10/LICENSE.txt

/bin/mkdirs $dpay/Examples/OpenStep-SDL2-2.32.10
/bin/mkdirs $dpay/Examples/OpenStep-SDL2-2.32.10/Upstream
/bin/mkdirs $dpay/Examples/OpenStep-SDL2-2.32.10/Support
/bin/mkdirs $dpay/Tools
cc -m486 -o $dpay/Tools/OpenStepSDL2Demos-Intel $marksrc
if ($status != 0) exit 1
chmod 555 $dpay/Tools/OpenStepSDL2Demos-Intel
cp $src/release-examples/sdl2/* $dpay/Examples/OpenStep-SDL2-2.32.10/
cp $src/upstream/SDL-2.32.10/test/testgl2.c $src/upstream/SDL-2.32.10/test/testspriteminimal.c $src/upstream/SDL-2.32.10/test/testmultiaudio.c $src/upstream/SDL-2.32.10/test/testthread.c $src/upstream/SDL-2.32.10/test/testtimer.c $src/upstream/SDL-2.32.10/test/testutils.c $src/upstream/SDL-2.32.10/test/testutils.h $src/upstream/SDL-2.32.10/test/icon.bmp $src/upstream/SDL-2.32.10/test/sample.wav $dpay/Examples/OpenStep-SDL2-2.32.10/Upstream/
cp $src/upstream/SDL-2.32.10/src/test/SDL_test_common.c $src/upstream/SDL-2.32.10/src/test/SDL_test_assert.c $src/upstream/SDL-2.32.10/src/test/SDL_test_log.c $src/upstream/SDL-2.32.10/src/test/SDL_test_font.c $src/upstream/SDL-2.32.10/src/test/SDL_test_memory.c $src/upstream/SDL-2.32.10/src/test/SDL_test_crc32.c $dpay/Examples/OpenStep-SDL2-2.32.10/Support/
chmod 555 $dpay/Examples/OpenStep-SDL2-2.32.10/build-sdl2-clear.csh
chmod 555 $dpay/Examples/OpenStep-SDL2-2.32.10/build-upstream-demos.csh
cc -m486 -arch i386 -D__OPENSTEP__ -I$hpay/Headers $src/release-examples/sdl2/sdl2_clear.c $out/libSDL2.a -L$work/mesa/Mesa-3.4.2/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit -o $dpay/Examples/OpenStep-SDL2-2.32.10/sdl2_clear
if ($status != 0) then
    echo "build-sdl2-split: cannot build i386 SDL2 demo"
    exit 1
endif
chmod 555 $dpay/Examples/OpenStep-SDL2-2.32.10/sdl2_clear
set demodir = $dpay/Examples/OpenStep-SDL2-2.32.10
set common = "$demodir/Support/SDL_test_common.c $demodir/Support/SDL_test_font.c $demodir/Support/SDL_test_memory.c $demodir/Support/SDL_test_crc32.c"
set flags = "-m486 -arch i386 -D__OPENSTEP__ -I$hpay/Headers -I$hpay/Headers/SDL2 -I$demodir/Upstream -I$demodir/Support"
set libraries = "$out/libSDL2.a -L$work/mesa/Mesa-3.4.2/lib -lGL -lm -framework AppKit -framework Foundation -framework SoundKit"
cc $flags $demodir/Upstream/testgl2.c $common $libraries -o $demodir/testgl2
if ($status != 0) exit 1
cc $flags $demodir/Upstream/testspriteminimal.c $demodir/Upstream/testutils.c $libraries -o $demodir/testspriteminimal
if ($status != 0) exit 1
cc $flags $demodir/Upstream/testmultiaudio.c $demodir/Upstream/testutils.c $libraries -o $demodir/testmultiaudio
if ($status != 0) exit 1
cc $flags $demodir/Upstream/testthread.c $common $demodir/Support/SDL_test_log.c $libraries -o $demodir/testthread
if ($status != 0) exit 1
cc $flags $demodir/Upstream/testtimer.c $common $demodir/Support/SDL_test_assert.c $demodir/Support/SDL_test_log.c $libraries -o $demodir/testtimer
if ($status != 0) exit 1
chmod 555 $demodir/sdl2_clear $demodir/testgl2 $demodir/testspriteminimal $demodir/testmultiaudio $demodir/testthread $demodir/testtimer
foreach demo ( $demodir/sdl2_clear $demodir/testgl2 $demodir/testspriteminimal $demodir/testmultiaudio $demodir/testthread $demodir/testtimer )
    file $demo | grep 'architecture i386' > /dev/null
    if ($status != 0) then
        echo "build-sdl2-split: demo is not i386 Mach-O: $demo"
        exit 1
    endif
end

/bin/mkdirs $dst
$pkgtool $lpay $linf -d $dst
if ($status != 0) exit 1
$pkgtool $hpay $hinf -d $dst
if ($status != 0) exit 1
$pkgtool $dpay $dinf -d $dst
if ($status != 0) exit 1
cp $pre $dst/OpenStepSDL2Libraries.pkg/OpenStepSDL2Libraries.pre_install
cp $post $dst/OpenStepSDL2Libraries.pkg/OpenStepSDL2Libraries.post_install
cp $hpre $dst/OpenStepSDL2Headers.pkg/OpenStepSDL2Headers.pre_install
cp $dpre $dst/OpenStepSDL2Demos.pkg/OpenStepSDL2Demos.pre_install
chmod 555 $dst/OpenStepSDL2Libraries.pkg/OpenStepSDL2Libraries.pre_install $dst/OpenStepSDL2Libraries.pkg/OpenStepSDL2Libraries.post_install
chmod 555 $dst/OpenStepSDL2Headers.pkg/OpenStepSDL2Headers.pre_install $dst/OpenStepSDL2Demos.pkg/OpenStepSDL2Demos.pre_install
if ($status != 0) exit 1
echo "build-sdl2-split: PASS Libraries, Headers and Demos packages in $dst"
