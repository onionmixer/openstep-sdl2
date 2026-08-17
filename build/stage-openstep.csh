#!/bin/csh -f
# Copy the read-only project export into the private OPENSTEP work tree.
# Never create, remove, chmod or redirect any file under /ndrv/openstep-sdl20.

set source_export = /ndrv
if ("$1" != "") set source_export = "$1"
set source_root = $source_export/openstep-sdl20
set work_root = /tmp/SDL20
set stage_root = $work_root/.src-staging

if (! -r $source_root/README.md) then
    echo "stage-openstep: cannot read $source_root/README.md"
    exit 2
endif
if (! -r $source_root/upstream/SDL-2.32.10/include/SDL.h) then
    echo "stage-openstep: missing verified SDL-2.32.10 source"
    exit 2
endif
if (! -r $source_root/upstream/MesaLib-3.4.2.tar.gz) then
    echo "stage-openstep: missing verified MesaLib-3.4.2 archive"
    exit 2
endif
if (! -r $source_root/packaging/openstep/build-split-packages.csh || ! -r $source_root/packaging/openstep/OpenStepSDL2Libraries.info || ! -r $source_root/packaging/openstep/OpenStepSDL2Headers.info || ! -r $source_root/packaging/openstep/OpenStepSDL2Demos.info || ! -r $source_root/packaging/openstep/OpenStepSDL2Headers.pre_install || ! -r $source_root/packaging/openstep/OpenStepSDL2Demos.pre_install || ! -r $source_root/release-docs/README.OPENSTEP || ! -r $source_root/release-examples/sdl2/sdl2_clear.c || ! -r $source_root/release-examples/sdl2/build-upstream-demos.csh || ! -r $source_root/port/openstep/src/cpuinfo/SDL_openstepcpuinfo.c) then
    echo "stage-openstep: missing SDL2 Installer packaging source"
    exit 2
endif

if (! -d $work_root) mkdir $work_root
if (! -d $work_root/log) mkdir $work_root/log
chmod 777 $work_root/log
if (! -d $work_root/bin) mkdir $work_root/bin
if (! -d $work_root/build) mkdir $work_root/build
if (! -d $work_root/mesa) mkdir $work_root/mesa

# This is intentionally the only recursive cleanup and its target is exact.
if (-d $stage_root) rm -rf $stage_root
mkdir $stage_root

# Historical OPENSTEP tar has a short pathname limit. Stage only the public
# headers and the explicit first compiler-gate source set, not the whole SDL
# tree, Xcode projects or upstream test suite.
set stage_archive = $work_root/.stage.tar
rm -f $stage_archive
(cd $source_root; tar cf $stage_archive README.md FEASIBILITY.md PORT_PLAN.md notes build port test/openstep upstream/SDL-2.32.10/LICENSE.txt upstream/SDL-2.32.10/include upstream/SDL-2.32.10/src/SDL.c upstream/SDL-2.32.10/src/SDL_assert.c upstream/SDL-2.32.10/src/SDL_dataqueue.c upstream/SDL-2.32.10/src/SDL_error.c upstream/SDL-2.32.10/src/SDL_hints.c upstream/SDL-2.32.10/src/SDL_list.c upstream/SDL-2.32.10/src/SDL_log.c upstream/SDL-2.32.10/src/SDL_utils.c upstream/SDL-2.32.10/src/SDL_internal.h upstream/SDL-2.32.10/src/SDL_assert_c.h upstream/SDL-2.32.10/src/SDL_dataqueue.h upstream/SDL-2.32.10/src/SDL_error_c.h upstream/SDL-2.32.10/src/SDL_hints_c.h upstream/SDL-2.32.10/src/SDL_list.h upstream/SDL-2.32.10/src/SDL_log_c.h upstream/SDL-2.32.10/src/SDL_utils_c.h upstream/SDL-2.32.10/src/core/linux/SDL_dbus.h upstream/SDL-2.32.10/src/events/SDL_events.c upstream/SDL-2.32.10/src/events/SDL_keyboard.c upstream/SDL-2.32.10/src/events/SDL_mouse.c upstream/SDL-2.32.10/src/events/SDL_windowevents.c upstream/SDL-2.32.10/src/events/SDL_quit.c upstream/SDL-2.32.10/src/events/SDL_events_c.h upstream/SDL-2.32.10/src/events/SDL_clipboardevents_c.h upstream/SDL-2.32.10/src/events/SDL_displayevents_c.h upstream/SDL-2.32.10/src/events/SDL_dropevents_c.h upstream/SDL-2.32.10/src/events/SDL_gesture_c.h upstream/SDL-2.32.10/src/events/SDL_keyboard_c.h upstream/SDL-2.32.10/src/events/SDL_mouse_c.h upstream/SDL-2.32.10/src/events/SDL_touch_c.h upstream/SDL-2.32.10/src/events/SDL_windowevents_c.h upstream/SDL-2.32.10/src/haptic/SDL_haptic_c.h upstream/SDL-2.32.10/src/joystick/SDL_joystick_c.h upstream/SDL-2.32.10/src/sensor/SDL_sensor_c.h upstream/SDL-2.32.10/src/render/SDL_sysrender.h upstream/SDL-2.32.10/src/render/SDL_yuv_sw_c.h upstream/SDL-2.32.10/src/video/SDL_video.c upstream/SDL-2.32.10/src/video/SDL_blit.h upstream/SDL-2.32.10/src/video/SDL_pixels_c.h upstream/SDL-2.32.10/src/video/SDL_rect_c.h upstream/SDL-2.32.10/src/video/SDL_sysvideo.h upstream/SDL-2.32.10/src/video/SDL_vulkan_internal.h upstream/SDL-2.32.10/src/atomic/SDL_atomic.c upstream/SDL-2.32.10/src/atomic/SDL_spinlock.c upstream/SDL-2.32.10/src/stdlib/SDL_malloc.c upstream/SDL-2.32.10/src/stdlib/SDL_string.c upstream/SDL-2.32.10/src/stdlib/SDL_getenv.c upstream/SDL-2.32.10/src/stdlib/SDL_iconv.c upstream/SDL-2.32.10/src/stdlib/SDL_vacopy.h upstream/SDL-2.32.10/src/thread/SDL_thread.c upstream/SDL-2.32.10/src/thread/SDL_thread_c.h upstream/SDL-2.32.10/src/thread/SDL_systhread.h upstream/SDL-2.32.10/src/thread/generic/SDL_systls.c upstream/SDL-2.32.10/src/thread/generic/SDL_systhread_c.h upstream/SDL-2.32.10/src/timer/SDL_timer.c upstream/SDL-2.32.10/src/timer/SDL_timer_c.h)
if ($status != 0) then
    echo "stage-openstep: source archive creation failed"
    rm -f $stage_archive
    exit 1
endif
(cd $source_root; tar rf $stage_archive upstream/SDL-2.32.10/src/events/scancodes_ascii.h upstream/SDL-2.32.10/src/video/SDL_rect.c upstream/SDL-2.32.10/src/video/SDL_rect_impl.h)
if ($status != 0) then
    echo "stage-openstep: core archive addition failed"
    rm -f $stage_archive
    exit 1
endif
(cd $stage_root; tar xf $stage_archive)
if ($status != 0) then
    echo "stage-openstep: source archive extraction failed"
    rm -f $stage_archive
    exit 1
endif
# OPENSTEP's tar only retained the first append operation above. These small
# rectangle-core files are copied from read-only NFS into the private stage
# after extraction; no source-export file is modified.
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_rect.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_rect_impl.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_clipboard.c $stage_root/upstream/SDL-2.32.10/src/video/
if ($status != 0) then
    echo "stage-openstep: rectangle/clipboard core copy failed"
    rm -f $stage_archive
    exit 1
endif
# Historical OPENSTEP tar can recreate the test/openstep directory without
# its files when it follows the long archive member list above.  The smoke
# programs are part of the target verification contract, so copy that small
# directory explicitly into the private stage after extraction.
if (! -d $stage_root/test) mkdir $stage_root/test
if (! -d $stage_root/test/openstep) mkdir $stage_root/test/openstep
cp $source_root/test/openstep/* $stage_root/test/openstep/
if ($status != 0) then
    echo "stage-openstep: OPENSTEP smoke test copy failed"
    rm -f $stage_archive
    exit 1
endif
# The Demos package ships selected unmodified upstream SDL consumers together
# with exactly the SDL_test support files and media each one needs.  Keep this
# explicit rather than staging the whole large upstream test tree.
if (! -d $stage_root/upstream/SDL-2.32.10/test) mkdir $stage_root/upstream/SDL-2.32.10/test
if (! -d $stage_root/upstream/SDL-2.32.10/src/test) mkdir $stage_root/upstream/SDL-2.32.10/src/test
cp $source_root/upstream/SDL-2.32.10/test/testgl2.c $source_root/upstream/SDL-2.32.10/test/testspriteminimal.c $source_root/upstream/SDL-2.32.10/test/testmultiaudio.c $source_root/upstream/SDL-2.32.10/test/testthread.c $source_root/upstream/SDL-2.32.10/test/testtimer.c $source_root/upstream/SDL-2.32.10/test/testutils.c $source_root/upstream/SDL-2.32.10/test/testutils.h $source_root/upstream/SDL-2.32.10/test/icon.bmp $source_root/upstream/SDL-2.32.10/test/sample.wav $stage_root/upstream/SDL-2.32.10/test/
cp $source_root/upstream/SDL-2.32.10/src/test/SDL_test_common.c $source_root/upstream/SDL-2.32.10/src/test/SDL_test_assert.c $source_root/upstream/SDL-2.32.10/src/test/SDL_test_log.c $source_root/upstream/SDL-2.32.10/src/test/SDL_test_font.c $source_root/upstream/SDL-2.32.10/src/test/SDL_test_memory.c $source_root/upstream/SDL-2.32.10/src/test/SDL_test_crc32.c $stage_root/upstream/SDL-2.32.10/src/test/
if ($status != 0) then
    echo "stage-openstep: SDL upstream demo source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/port/openstep/src/cpuinfo) mkdir $stage_root/port/openstep/src/cpuinfo
cp $source_root/port/openstep/src/cpuinfo/SDL_openstepcpuinfo.c $stage_root/port/openstep/src/cpuinfo/
if ($status != 0) then
    echo "stage-openstep: OPENSTEP CPU information source copy failed"
    rm -f $stage_archive
    exit 1
endif
cp -R $source_root/packaging $stage_root/
cp -R $source_root/release-packaging $stage_root/
cp -R $source_root/release-docs $stage_root/
cp -R $source_root/release-examples $stage_root/
if ($status != 0) then
    echo "stage-openstep: SDL2 Installer packaging copy failed"
    rm -f $stage_archive
    exit 1
endif
# Mesa's historical OpenStep target builds in-tree.  Keep that mutable tree
# outside src: every SDL source refresh above deliberately recreates src, but
# must never discard already verified Mesa libraries.  The archive is copied
# and extracted only for the initial private Mesa stage.
set mesa_root = $work_root/mesa/Mesa-3.4.2
if (! -r $mesa_root/Make-config || ! -r $mesa_root/docs/README.OpenStep) then
    if (-d $mesa_root) rm -rf $mesa_root
    cp $source_root/upstream/MesaLib-3.4.2.tar.gz $work_root/.MesaLib-3.4.2.tar.gz
    if ($status != 0) then
        echo "stage-openstep: Mesa-3.4.2 archive copy failed"
        rm -f $stage_archive
        exit 1
    endif
    (cd $work_root/mesa; gzip -dc $work_root/.MesaLib-3.4.2.tar.gz | tar xf -)
    set mesaextractstatus = $status
    rm -f $work_root/.MesaLib-3.4.2.tar.gz
    if ($mesaextractstatus != 0) then
        echo "stage-openstep: Mesa-3.4.2 archive extraction failed"
        rm -f $stage_archive
        exit 1
    endif
endif
cp $source_root/upstream/SDL-2.32.10/src/events/*.c $stage_root/upstream/SDL-2.32.10/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/*.h $stage_root/upstream/SDL-2.32.10/src/events/
if ($status != 0) then
    echo "stage-openstep: full event source copy failed"
    rm -f $stage_archive
    exit 1
endif
cp $source_root/upstream/SDL-2.32.10/src/sensor/SDL_sensor.c $stage_root/upstream/SDL-2.32.10/src/sensor/
cp $source_root/upstream/SDL-2.32.10/src/sensor/SDL_syssensor.h $stage_root/upstream/SDL-2.32.10/src/sensor/
mkdir $stage_root/upstream/SDL-2.32.10/src/sensor/dummy
cp $source_root/upstream/SDL-2.32.10/src/sensor/dummy/SDL_dummysensor.c $stage_root/upstream/SDL-2.32.10/src/sensor/dummy/
cp $source_root/upstream/SDL-2.32.10/src/sensor/dummy/SDL_dummysensor.h $stage_root/upstream/SDL-2.32.10/src/sensor/dummy/
if ($status != 0) then
    echo "stage-openstep: dummy sensor source copy failed"
    rm -f $stage_archive
    exit 1
endif
mkdir $stage_root/upstream/SDL-2.32.10/src/audio
mkdir $stage_root/upstream/SDL-2.32.10/src/audio/dummy
cp $source_root/upstream/SDL-2.32.10/src/audio/*.c $stage_root/upstream/SDL-2.32.10/src/audio/
cp $source_root/upstream/SDL-2.32.10/src/audio/*.h $stage_root/upstream/SDL-2.32.10/src/audio/
cp $source_root/upstream/SDL-2.32.10/src/audio/dummy/SDL_dummyaudio.c $stage_root/upstream/SDL-2.32.10/src/audio/dummy/
cp $source_root/upstream/SDL-2.32.10/src/audio/dummy/SDL_dummyaudio.h $stage_root/upstream/SDL-2.32.10/src/audio/dummy/
if ($status != 0) then
    echo "stage-openstep: audio core source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/joystick) mkdir $stage_root/upstream/SDL-2.32.10/src/joystick
if (! -d $stage_root/upstream/SDL-2.32.10/src/joystick/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/joystick/dummy
if (! -d $stage_root/upstream/SDL-2.32.10/src/joystick/hidapi) mkdir $stage_root/upstream/SDL-2.32.10/src/joystick/hidapi
cp $source_root/upstream/SDL-2.32.10/src/joystick/*.c $stage_root/upstream/SDL-2.32.10/src/joystick/
cp $source_root/upstream/SDL-2.32.10/src/joystick/*.h $stage_root/upstream/SDL-2.32.10/src/joystick/
cp $source_root/upstream/SDL-2.32.10/src/joystick/dummy/SDL_sysjoystick.c $stage_root/upstream/SDL-2.32.10/src/joystick/dummy/
cp $source_root/upstream/SDL-2.32.10/src/joystick/hidapi/*.h $stage_root/upstream/SDL-2.32.10/src/joystick/hidapi/
if ($status != 0) then
    echo "stage-openstep: joystick core source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/haptic) mkdir $stage_root/upstream/SDL-2.32.10/src/haptic
if (! -d $stage_root/upstream/SDL-2.32.10/src/haptic/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/haptic/dummy
cp $source_root/upstream/SDL-2.32.10/src/haptic/*.c $stage_root/upstream/SDL-2.32.10/src/haptic/
cp $source_root/upstream/SDL-2.32.10/src/haptic/*.h $stage_root/upstream/SDL-2.32.10/src/haptic/
cp $source_root/upstream/SDL-2.32.10/src/haptic/dummy/SDL_syshaptic.c $stage_root/upstream/SDL-2.32.10/src/haptic/dummy/
if ($status != 0) then
    echo "stage-openstep: haptic core source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/loadso) mkdir $stage_root/upstream/SDL-2.32.10/src/loadso
if (! -d $stage_root/upstream/SDL-2.32.10/src/loadso/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/loadso/dummy
if (! -d $stage_root/upstream/SDL-2.32.10/src/filesystem) mkdir $stage_root/upstream/SDL-2.32.10/src/filesystem
if (! -d $stage_root/upstream/SDL-2.32.10/src/filesystem/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/filesystem/dummy
if (! -d $stage_root/upstream/SDL-2.32.10/src/locale) mkdir $stage_root/upstream/SDL-2.32.10/src/locale
if (! -d $stage_root/upstream/SDL-2.32.10/src/locale/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/locale/dummy
if (! -d $stage_root/upstream/SDL-2.32.10/src/power) mkdir $stage_root/upstream/SDL-2.32.10/src/power
cp $source_root/upstream/SDL-2.32.10/src/loadso/dummy/SDL_sysloadso.c $stage_root/upstream/SDL-2.32.10/src/loadso/dummy/
cp $source_root/upstream/SDL-2.32.10/src/filesystem/dummy/SDL_sysfilesystem.c $stage_root/upstream/SDL-2.32.10/src/filesystem/dummy/
cp $source_root/upstream/SDL-2.32.10/src/locale/SDL_locale.c $stage_root/upstream/SDL-2.32.10/src/locale/
cp $source_root/upstream/SDL-2.32.10/src/locale/SDL_syslocale.h $stage_root/upstream/SDL-2.32.10/src/locale/
cp $source_root/upstream/SDL-2.32.10/src/locale/dummy/SDL_syslocale.c $stage_root/upstream/SDL-2.32.10/src/locale/dummy/
cp $source_root/upstream/SDL-2.32.10/src/power/SDL_power.c $stage_root/upstream/SDL-2.32.10/src/power/
cp $source_root/upstream/SDL-2.32.10/src/power/SDL_syspower.h $stage_root/upstream/SDL-2.32.10/src/power/
if ($status != 0) then
    echo "stage-openstep: standard fallback source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/misc) mkdir $stage_root/upstream/SDL-2.32.10/src/misc
if (! -d $stage_root/upstream/SDL-2.32.10/src/misc/dummy) mkdir $stage_root/upstream/SDL-2.32.10/src/misc/dummy
cp $source_root/upstream/SDL-2.32.10/src/misc/SDL_url.c $stage_root/upstream/SDL-2.32.10/src/misc/
cp $source_root/upstream/SDL-2.32.10/src/misc/SDL_sysurl.h $stage_root/upstream/SDL-2.32.10/src/misc/
cp $source_root/upstream/SDL-2.32.10/src/misc/dummy/SDL_sysurl.c $stage_root/upstream/SDL-2.32.10/src/misc/dummy/
if ($status != 0) then
    echo "stage-openstep: dummy URL source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/file) mkdir $stage_root/upstream/SDL-2.32.10/src/file
if (! -d $stage_root/upstream/SDL-2.32.10/src/hidapi) mkdir $stage_root/upstream/SDL-2.32.10/src/hidapi
cp $source_root/upstream/SDL-2.32.10/src/SDL_guid.c $stage_root/upstream/SDL-2.32.10/src/
cp $source_root/upstream/SDL-2.32.10/src/file/SDL_rwops.c $stage_root/upstream/SDL-2.32.10/src/file/
cp $source_root/upstream/SDL-2.32.10/src/hidapi/SDL_hidapi.c $stage_root/upstream/SDL-2.32.10/src/hidapi/
cp $source_root/upstream/SDL-2.32.10/src/hidapi/SDL_hidapi_c.h $stage_root/upstream/SDL-2.32.10/src/hidapi/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_crc16.c $stage_root/upstream/SDL-2.32.10/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_crc32.c $stage_root/upstream/SDL-2.32.10/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_qsort.c $stage_root/upstream/SDL-2.32.10/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_strtokr.c $stage_root/upstream/SDL-2.32.10/src/stdlib/
if ($status != 0) then
    echo "stage-openstep: common utility/HID fallback source copy failed"
    rm -f $stage_archive
    exit 1
endif
if (! -d $stage_root/upstream/SDL-2.32.10/src/render/software) mkdir $stage_root/upstream/SDL-2.32.10/src/render/software
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_render.c $stage_root/upstream/SDL-2.32.10/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_yuv_sw.c $stage_root/upstream/SDL-2.32.10/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_yuv_sw_c.h $stage_root/upstream/SDL-2.32.10/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/software/*.c $stage_root/upstream/SDL-2.32.10/src/render/software/
cp $source_root/upstream/SDL-2.32.10/src/render/software/*.h $stage_root/upstream/SDL-2.32.10/src/render/software/
if ($status != 0) then
    echo "stage-openstep: software renderer source copy failed"
    rm -f $stage_archive
    exit 1
endif
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_surface.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_pixels.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_bmp.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_shape.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_shape_internals.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_RLEaccel_c.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_yuv_c.h $stage_root/upstream/SDL-2.32.10/src/video/
if ($status != 0) then
    echo "stage-openstep: surface/BMP/shape core copy failed"
    rm -f $stage_archive
    exit 1
endif
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_0.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_1.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_A.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_N.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_auto.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_copy.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_slow.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_auto.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_copy.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_slow.h $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_RLEaccel.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_yuv.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_stretch.c $stage_root/upstream/SDL-2.32.10/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_fillrect.c $stage_root/upstream/SDL-2.32.10/src/video/
if ($status != 0) then
    echo "stage-openstep: software blit source copy failed"
    rm -f $stage_archive
    exit 1
endif
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_stdlib.c $stage_root/upstream/SDL-2.32.10/src/stdlib/
if ($status != 0) then
    echo "stage-openstep: SDL stdlib math wrapper copy failed"
    rm -f $stage_archive
    exit 1
endif
mkdir $stage_root/upstream/SDL-2.32.10/src/video/yuv2rgb
# SDL's yuv2rgb implementation is a family of translation units.  Keep the
# complete upstream family in the private stage; i486 builds select its C
# implementation because __SSE2__ and __loongarch_sx are both absent.
cp $source_root/upstream/SDL-2.32.10/src/video/yuv2rgb/*.h $stage_root/upstream/SDL-2.32.10/src/video/yuv2rgb/
cp $source_root/upstream/SDL-2.32.10/src/video/yuv2rgb/*.c $stage_root/upstream/SDL-2.32.10/src/video/yuv2rgb/
if ($status != 0) then
    echo "stage-openstep: YUV conversion source copy failed"
    rm -f $stage_archive
    exit 1
endif
mkdir $stage_root/upstream/SDL-2.32.10/src/cpuinfo
cp $source_root/upstream/SDL-2.32.10/src/cpuinfo/SDL_cpuinfo.c $stage_root/upstream/SDL-2.32.10/src/cpuinfo/
if ($status != 0) then
    echo "stage-openstep: CPU information source copy failed"
    rm -f $stage_archive
    exit 1
endif
mkdir $stage_root/upstream/SDL-2.32.10/src/libm
cp $source_root/upstream/SDL-2.32.10/src/libm/*.c $stage_root/upstream/SDL-2.32.10/src/libm/
cp $source_root/upstream/SDL-2.32.10/src/libm/*.h $stage_root/upstream/SDL-2.32.10/src/libm/
if ($status != 0) then
    echo "stage-openstep: SDL libm source copy failed"
    rm -f $stage_archive
    exit 1
endif
rm -f $stage_archive

# Do not discard a known-good private tree until every NFS read, archive
# extraction and explicit post-copy has completed.  Rename its old directory
# aside first, then restore it if the same-filesystem commit rename fails.
set previous_root = $work_root/.src-previous
if (-d $previous_root) rm -rf $previous_root
if (-d $work_root/src) then
    mv $work_root/src $previous_root
    if ($status != 0) then
        echo "stage-openstep: cannot preserve current private source stage"
        exit 1
    endif
endif
mv $stage_root $work_root/src
if ($status != 0) then
    echo "stage-openstep: cannot commit private source stage"
    if (-d $previous_root) mv $previous_root $work_root/src
    exit 1
endif
if (-d $previous_root) rm -rf $previous_root

echo "stage-openstep: ready at $work_root/src"
