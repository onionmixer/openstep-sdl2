#!/bin/csh -f
# Make a writable SDL2 build overlay. The staged source tree is never
# modified; all generated files and objects remain under /tmp/SDL20/build.

set source_root = /tmp/SDL20/src
set build_root = /tmp/SDL20/build/SDL-2.32.10-openstep

if (! -r $source_root/upstream/SDL-2.32.10/include/SDL.h) then
    echo "prepare-openstep: run stage-openstep.csh after importing SDL first"
    exit 2
endif

if (-d $build_root) rm -rf $build_root
mkdir $build_root
cp -R $source_root/upstream/SDL-2.32.10/include $build_root/
cp $source_root/upstream/SDL-2.32.10/LICENSE.txt $build_root/
if (! -d $build_root/src) mkdir $build_root/src
cp $source_root/upstream/SDL-2.32.10/src/*.c $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_internal.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_dataqueue.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_error_c.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_hints_c.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_list.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_log_c.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/SDL_utils_c.h $build_root/src/
if (! -d $build_root/src/atomic) mkdir $build_root/src/atomic
if (! -d $build_root/src/audio) mkdir $build_root/src/audio
if (! -d $build_root/src/audio/dummy) mkdir $build_root/src/audio/dummy
if (! -d $build_root/src/audio/openstep) mkdir $build_root/src/audio/openstep
if (! -d $build_root/src/cpuinfo) mkdir $build_root/src/cpuinfo
if (! -d $build_root/src/stdlib) mkdir $build_root/src/stdlib
if (! -d $build_root/src/dynapi) mkdir $build_root/src/dynapi
if (! -d $build_root/src/core) mkdir $build_root/src/core
if (! -d $build_root/src/core/linux) mkdir $build_root/src/core/linux
if (! -d $build_root/src/events) mkdir $build_root/src/events
if (! -d $build_root/src/haptic) mkdir $build_root/src/haptic
if (! -d $build_root/src/haptic/dummy) mkdir $build_root/src/haptic/dummy
if (! -d $build_root/src/joystick) mkdir $build_root/src/joystick
if (! -d $build_root/src/joystick/dummy) mkdir $build_root/src/joystick/dummy
if (! -d $build_root/src/joystick/hidapi) mkdir $build_root/src/joystick/hidapi
if (! -d $build_root/src/loadso) mkdir $build_root/src/loadso
if (! -d $build_root/src/loadso/dummy) mkdir $build_root/src/loadso/dummy
if (! -d $build_root/src/filesystem) mkdir $build_root/src/filesystem
if (! -d $build_root/src/filesystem/dummy) mkdir $build_root/src/filesystem/dummy
if (! -d $build_root/src/file) mkdir $build_root/src/file
if (! -d $build_root/src/hidapi) mkdir $build_root/src/hidapi
if (! -d $build_root/src/locale) mkdir $build_root/src/locale
if (! -d $build_root/src/locale/dummy) mkdir $build_root/src/locale/dummy
if (! -d $build_root/src/misc) mkdir $build_root/src/misc
if (! -d $build_root/src/misc/dummy) mkdir $build_root/src/misc/dummy
if (! -d $build_root/src/power) mkdir $build_root/src/power
if (! -d $build_root/src/sensor) mkdir $build_root/src/sensor
if (! -d $build_root/src/sensor/dummy) mkdir $build_root/src/sensor/dummy
if (! -d $build_root/src/libm) mkdir $build_root/src/libm
if (! -d $build_root/src/render) mkdir $build_root/src/render
if (! -d $build_root/src/render/software) mkdir $build_root/src/render/software
if (! -d $build_root/src/thread) mkdir $build_root/src/thread
if (! -d $build_root/src/thread/generic) mkdir $build_root/src/thread/generic
if (! -d $build_root/src/thread/openstep) mkdir $build_root/src/thread/openstep
if (! -d $build_root/src/timer) mkdir $build_root/src/timer
if (! -d $build_root/src/video) mkdir $build_root/src/video
if (! -d $build_root/src/video/yuv2rgb) mkdir $build_root/src/video/yuv2rgb
if (! -d $build_root/src/video/openstep) mkdir $build_root/src/video/openstep
cp $source_root/upstream/SDL-2.32.10/src/SDL_assert_c.h $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/core/linux/SDL_dbus.h $build_root/src/core/linux/
cp $source_root/upstream/SDL-2.32.10/src/audio/*.c $build_root/src/audio/
cp $source_root/upstream/SDL-2.32.10/src/audio/*.h $build_root/src/audio/
cp $source_root/upstream/SDL-2.32.10/src/audio/dummy/SDL_dummyaudio.c $build_root/src/audio/dummy/
cp $source_root/upstream/SDL-2.32.10/src/audio/dummy/SDL_dummyaudio.h $build_root/src/audio/dummy/
cp $source_root/port/openstep/src/audio/openstep/SDL_openstepaudio.h $build_root/src/audio/openstep/
cp $source_root/port/openstep/src/audio/openstep/SDL_openstepaudio.m $build_root/src/audio/openstep/
cp $source_root/upstream/SDL-2.32.10/src/joystick/*.c $build_root/src/joystick/
cp $source_root/upstream/SDL-2.32.10/src/joystick/*.h $build_root/src/joystick/
cp $source_root/upstream/SDL-2.32.10/src/joystick/dummy/SDL_sysjoystick.c $build_root/src/joystick/dummy/
cp $source_root/upstream/SDL-2.32.10/src/joystick/hidapi/*.h $build_root/src/joystick/hidapi/
cp $source_root/upstream/SDL-2.32.10/src/haptic/*.c $build_root/src/haptic/
cp $source_root/upstream/SDL-2.32.10/src/haptic/*.h $build_root/src/haptic/
cp $source_root/upstream/SDL-2.32.10/src/haptic/dummy/SDL_syshaptic.c $build_root/src/haptic/dummy/
cp $source_root/upstream/SDL-2.32.10/src/loadso/dummy/SDL_sysloadso.c $build_root/src/loadso/dummy/
cp $source_root/upstream/SDL-2.32.10/src/filesystem/dummy/SDL_sysfilesystem.c $build_root/src/filesystem/dummy/
cp $source_root/upstream/SDL-2.32.10/src/locale/SDL_locale.c $build_root/src/locale/
cp $source_root/upstream/SDL-2.32.10/src/locale/SDL_syslocale.h $build_root/src/locale/
cp $source_root/upstream/SDL-2.32.10/src/locale/dummy/SDL_syslocale.c $build_root/src/locale/dummy/
cp $source_root/upstream/SDL-2.32.10/src/misc/SDL_url.c $build_root/src/misc/
cp $source_root/upstream/SDL-2.32.10/src/misc/SDL_sysurl.h $build_root/src/misc/
cp $source_root/upstream/SDL-2.32.10/src/misc/dummy/SDL_sysurl.c $build_root/src/misc/dummy/
cp $source_root/upstream/SDL-2.32.10/src/power/SDL_power.c $build_root/src/power/
cp $source_root/upstream/SDL-2.32.10/src/power/SDL_syspower.h $build_root/src/power/
cp $source_root/upstream/SDL-2.32.10/src/SDL_guid.c $build_root/src/
cp $source_root/upstream/SDL-2.32.10/src/file/SDL_rwops.c $build_root/src/file/
cp $source_root/upstream/SDL-2.32.10/src/hidapi/SDL_hidapi.c $build_root/src/hidapi/
cp $source_root/upstream/SDL-2.32.10/src/hidapi/SDL_hidapi_c.h $build_root/src/hidapi/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_crc16.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_crc32.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_qsort.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_strtokr.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_render.c $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_yuv_sw.c $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_yuv_sw_c.h $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/software/*.c $build_root/src/render/software/
cp $source_root/upstream/SDL-2.32.10/src/render/software/*.h $build_root/src/render/software/
cp $source_root/port/openstep/src/render/SDL_opensteprenderchecks.h $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/events/*.h $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/SDL_events.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/SDL_keyboard.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/SDL_mouse.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/SDL_windowevents.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/SDL_quit.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/events/*.c $build_root/src/events/
cp $source_root/upstream/SDL-2.32.10/src/haptic/SDL_haptic_c.h $build_root/src/haptic/
cp $source_root/upstream/SDL-2.32.10/src/joystick/SDL_joystick_c.h $build_root/src/joystick/
cp $source_root/upstream/SDL-2.32.10/src/sensor/SDL_sensor_c.h $build_root/src/sensor/
cp $source_root/upstream/SDL-2.32.10/src/sensor/SDL_sensor.c $build_root/src/sensor/
cp $source_root/upstream/SDL-2.32.10/src/sensor/SDL_syssensor.h $build_root/src/sensor/
cp $source_root/upstream/SDL-2.32.10/src/sensor/dummy/SDL_dummysensor.c $build_root/src/sensor/dummy/
cp $source_root/upstream/SDL-2.32.10/src/sensor/dummy/SDL_dummysensor.h $build_root/src/sensor/dummy/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_sysrender.h $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/render/SDL_yuv_sw_c.h $build_root/src/render/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_video.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_clipboard.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_bmp.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_shape.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_shape_internals.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_pixels_c.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_rect_c.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_rect.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_rect_impl.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_surface.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_pixels.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_RLEaccel_c.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_yuv_c.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit*.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_auto.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_copy.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_blit_slow.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_RLEaccel.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_yuv.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_stretch.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_fillrect.c $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/yuv2rgb/*.h $build_root/src/video/yuv2rgb/
cp $source_root/upstream/SDL-2.32.10/src/video/yuv2rgb/*.c $build_root/src/video/yuv2rgb/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_sysvideo.h $build_root/src/video/
cp $source_root/upstream/SDL-2.32.10/src/video/SDL_vulkan_internal.h $build_root/src/video/
cp $source_root/port/openstep/src/video/openstep/SDL_openstepvideo.h $build_root/src/video/openstep/
cp $source_root/port/openstep/src/video/openstep/SDL_openstepvideo.m $build_root/src/video/openstep/
cp $source_root/upstream/SDL-2.32.10/src/atomic/SDL_atomic.c $build_root/src/atomic/
cp $source_root/upstream/SDL-2.32.10/src/atomic/SDL_spinlock.c $build_root/src/atomic/
cp $source_root/upstream/SDL-2.32.10/src/cpuinfo/SDL_cpuinfo.c $build_root/src/cpuinfo/
cp $source_root/port/openstep/src/cpuinfo/SDL_openstepcpuinfo.c $build_root/src/cpuinfo/
cp $source_root/upstream/SDL-2.32.10/src/libm/*.c $build_root/src/libm/
cp $source_root/upstream/SDL-2.32.10/src/libm/*.h $build_root/src/libm/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_malloc.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_stdlib.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_string.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_getenv.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_iconv.c $build_root/src/stdlib/
cp $source_root/upstream/SDL-2.32.10/src/stdlib/SDL_vacopy.h $build_root/src/stdlib/
cp $source_root/port/openstep/src/stdlib/SDL_vacopy.h $build_root/src/stdlib/
cp $source_root/port/openstep/src/stdlib/SDL_stdlib_compat.c $build_root/src/stdlib/
cp $source_root/port/openstep/src/dynapi/SDL_dynapi.h $build_root/src/dynapi/
cp $source_root/upstream/SDL-2.32.10/src/thread/SDL_thread.c $build_root/src/thread/
cp $source_root/upstream/SDL-2.32.10/src/thread/SDL_thread_c.h $build_root/src/thread/
cp $source_root/upstream/SDL-2.32.10/src/thread/SDL_systhread.h $build_root/src/thread/
cp $source_root/upstream/SDL-2.32.10/src/thread/generic/SDL_systls.c $build_root/src/thread/generic/
cp $source_root/upstream/SDL-2.32.10/src/thread/generic/SDL_systhread_c.h $build_root/src/thread/generic/
cp $source_root/port/openstep/src/thread/openstep/SDL_systhread_c.h $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/thread/openstep/SDL_systls.c $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/thread/openstep/SDL_systhread.c $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/thread/openstep/SDL_sysmutex.c $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/thread/openstep/SDL_syssem.c $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/thread/openstep/SDL_syscond.c $build_root/src/thread/openstep/
cp $source_root/port/openstep/src/timer/SDL_systimer.c $build_root/src/timer/
cp $source_root/port/openstep/src/core/SDL_maincore.c $build_root/src/core/
cp $source_root/port/openstep/src/core/SDL_maincore.h $build_root/src/core/
cp $source_root/upstream/SDL-2.32.10/src/timer/SDL_timer.c $build_root/src/timer/
cp $source_root/upstream/SDL-2.32.10/src/timer/SDL_timer_c.h $build_root/src/timer/
if ($status != 0) then
    echo "prepare-openstep: upstream copy failed"
    exit 1
endif

# OPENSTEP's BSD headers already typedef u_int32_t.  SDL's uClibc math
# fallback only needs to avoid repeating that typedef in the private overlay.
ed - $build_root/src/libm/math_private.h << EOF
/^#if !defined(__HAIKU__)/c
#if !defined(__OPENSTEP__) && !defined(__HAIKU__) && !defined(__PSP__) && !defined(__3DS__) && !defined(__PS2__)
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: SDL libm typedef compatibility insertion failed"
    exit 1
endif

# The target ed cannot open this large source file. Insert the bootstrap in
# the private overlay with the target's C89-era awk instead.
set video_source = $build_root/src/video/SDL_video.c
awk '{ print $0; if ($0 == "static VideoBootStrap *bootstrap[] = {") { print "#ifdef SDL_VIDEO_DRIVER_OPENSTEP"; print "    &OPENSTEP_bootstrap,"; print "#endif"; } }' $video_source > $video_source.bootstrap
if ($status != 0) then
    echo "prepare-openstep: video bootstrap insertion failed"
    exit 1
endif
mv -f $video_source.bootstrap $video_source

# GCC 2.7 cpp rejects an empty macro argument. SDL_video.c uses CHECK_*(_, )
# in void functions. sed is used here because the target ed cannot open this
# large source file; only the private /tmp overlay is rewritten.
sed -e 's/CHECK_WINDOW_MAGIC(window, );/CHECK_WINDOW_MAGIC(window, SDL_OPENSTEP_VOID_RETURN);/g' -e 's/CHECK_DISPLAY_INDEX(displayIndex, );/CHECK_DISPLAY_INDEX(displayIndex, SDL_OPENSTEP_VOID_RETURN);/g' $video_source > $video_source.openstep
if ($status != 0) then
    echo "prepare-openstep: video void-check compatibility transform failed"
    exit 1
endif
mv -f $video_source.openstep $video_source

# GCC 2.7 has the same empty-macro-argument limitation in the common
# joystick source. Preserve the upstream macro's void-return behavior by
# passing the existing empty expansion token in the private overlay.
set joystick_source = $build_root/src/joystick/SDL_joystick.c
sed -e 's/CHECK_JOYSTICK_MAGIC(joystick, );/CHECK_JOYSTICK_MAGIC(joystick, SDL_OPENSTEP_VOID_RETURN);/g' $joystick_source > $joystick_source.openstep
if ($status != 0) then
    echo "prepare-openstep: joystick void-check compatibility transform failed"
    exit 1
endif
mv -f $joystick_source.openstep $joystick_source

# SDL_hidapi.c retains its public disabled-HIDAPI fallbacks on OPENSTEP, but
# GCC 2.7 cannot parse the one empty macro argument used by its void close
# function. Rewrite only the private overlay call with the macro's exact
# invalid-device semantics; pristine upstream source remains untouched.
set hidapi_source = $build_root/src/hidapi/SDL_hidapi.c
sed -e 's/CHECK_DEVICE_MAGIC(device, );/if (device == NULL || device->magic != \&device_magic) { SDL_SetError("Invalid device"); return; }/g' $hidapi_source > $hidapi_source.openstep
if ($status != 0) then
    echo "prepare-openstep: HIDAPI void-check compatibility transform failed"
    exit 1
endif
mv -f $hidapi_source.openstep $hidapi_source

# GCC 2.7 also rejects the common renderer's empty return argument. Unlike
# the earlier checks, this macro nests another macro, so an empty expansion
# would become an invalid nested argument. Include short private helper
# definitions after the renderer magic objects and redirect only the affected
# void-return call sites.
set render_source = $build_root/src/render/SDL_render.c
sed -e 's/CHECK_RENDERER_MAGIC(renderer, );/if (SDL_OpenStepRendererMagicValid(renderer) == 0) return;/g' -e 's/CHECK_RENDERER_MAGIC(renderer, )/if (SDL_OpenStepRendererMagicValid(renderer) == 0) return;/g' -e 's/CHECK_TEXTURE_MAGIC(texture, );/if (SDL_OpenStepTextureMagicValid(texture) == 0) return;/g' -e 's/CHECK_RENDERER_MAGIC_BUT_NOT_DESTROYED_FLAG(renderer,);/if (SDL_OpenStepRendererMagicValidAllowDestroyed(renderer) == 0) return;/g' $render_source > $render_source.openstep
if ($status != 0) then
    echo "prepare-openstep: renderer void-check compatibility transform failed"
    exit 1
endif
mv -f $render_source.openstep $render_source
awk '{ print $0; if ($0 == "static char texture_magic;") print "#include \"SDL_opensteprenderchecks.h\""; }' $render_source > $render_source.voidchecks1
if ($status != 0) then
    echo "prepare-openstep: renderer void-check header insertion failed"
    exit 1
endif
mv -f $render_source.voidchecks1 $render_source

# The target ed cannot safely rewrite the full audio core either. Register
# the native SoundKit bootstrap only in the private build overlay.
set audio_source = $build_root/src/audio/SDL_audio.c
awk '{ print $0; if ($0 == "static const AudioBootStrap *const bootstrap[] = {") { print "#ifdef SDL_AUDIO_DRIVER_OPENSTEP"; print "    &OPENSTEPAUDIO_bootstrap,"; print "#endif"; } }' $audio_source > $audio_source.bootstrap
if ($status != 0) then
    echo "prepare-openstep: audio bootstrap insertion failed"
    exit 1
endif
mv -f $audio_source.bootstrap $audio_source

ed - $build_root/src/video/SDL_sysvideo.h << EOF
/^extern VideoBootStrap COCOA_bootstrap;\$/a
extern VideoBootStrap OPENSTEP_bootstrap;
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: video bootstrap declaration insertion failed"
    exit 1
endif

cp $source_root/port/openstep/include/SDL_config_openstep.h $build_root/include/
cp $source_root/port/openstep/include/stdint.h $build_root/include/
if ($status != 0) then
    echo "prepare-openstep: configuration overlay copy failed"
    exit 1
endif

ed - $build_root/src/thread/SDL_thread_c.h << EOF
/^#elif defined(SDL_THREAD_PTHREAD)/i
#elif defined(SDL_THREAD_OPENSTEP)
#include "openstep/SDL_systhread_c.h"
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: thread backend selection insertion failed"
    exit 1
endif

# OPENSTEP has no patch(1). Insert the platform selection only in the private
# /tmp overlay with native ed(1); pristine upstream remains unchanged.
ed - $build_root/include/SDL_config.h << EOF
/^#else\$/i
#elif defined(__OPENSTEP__)
#include "SDL_config_openstep.h"
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: configuration bootstrap insertion failed"
    exit 1
endif

ed - $build_root/src/audio/SDL_sysaudio.h << EOF
/^extern AudioBootStrap DUMMYAUDIO_bootstrap;\$/a
extern AudioBootStrap OPENSTEPAUDIO_bootstrap;
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: audio bootstrap declaration insertion failed"
    exit 1
endif

# GCC 2.7 cannot parse modern __attribute__((packed)) syntax. On this i386
# ABI the audio conversion structure has its natural SDL2 layout; keep the
# upstream packing request for GCC 3 and later.
ed - $build_root/include/SDL_audio.h << EOF
/^#if defined(__GNUC__) && !defined(__CHERI_PURE_CAPABILITY__)\$/c
#if defined(__GNUC__) && (__GNUC__ >= 3) && !defined(__CHERI_PURE_CAPABILITY__)
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: audio header compatibility insertion failed"
    exit 1
endif

# NeXT cc-744.13 identifies as GCC but rejects SDL's modern noreturn
# attribute spelling. Let begin_code.h select its empty portable branch only
# for OPENSTEP; this changes no public ABI and avoids macro redefinition.
ed - $build_root/include/begin_code.h << EOF
/^#ifndef SDL_NORETURN\$/+1c
#if defined(__GNUC__) && !defined(__OPENSTEP__)
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: noreturn compatibility insertion failed"
    exit 1
endif

# SDL2 assumes every GNU i386 assembler knows the Pentium PAUSE mnemonic.
# OPENSTEP's GCC 2.7 i486 assembler rejects it. Keep the busy-wait hint as a
# harmless i486 NOP for this exact target and leave all other platforms alone.
ed - $build_root/include/SDL_atomic.h << EOF
/SDL_CPUPauseInstruction() __asm__/c
#if defined(__OPENSTEP__)
#define SDL_CPUPauseInstruction() __asm__ __volatile__("nop")
#else
#define SDL_CPUPauseInstruction() __asm__ __volatile__("pause\n")
#endif
.
w
q
EOF
if ($status != 0) then
    echo "prepare-openstep: i486 atomic pause insertion failed"
    exit 1
endif

echo "prepare-openstep: writable source ready at $build_root"
