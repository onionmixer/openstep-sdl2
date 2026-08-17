#!/bin/sh
# Host-side structural checks for the evolving OPENSTEP static-archive path.
# This intentionally verifies source wiring only; target cc/ar/nm execution is
# still required before any archive gains runtime or release status.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/.." && pwd)

require() {
    file=$1
    fragment=$2
    if ! grep -F -q "$fragment" "$file"; then
        echo "check-openstep-archive-source: missing '$fragment' in $file" >&2
        exit 1
    fi
}

stage="$root/build/stage-openstep.csh"
closure="$root/build/link-sdl-init-closure-gate.csh"
archive="$root/build/build-sdl2-openstep-diagnostic-archive.csh"
report="$root/build/report-sdl2-openstep-manifest.csh"
final_check="$root/build/check-final-api-manifest.csh"
release_archive="$root/build/build-sdl2-openstep-release-archive.csh"
bmp_gate="$root/build/compile-sdl-bmp-gate.csh"
shape_gate="$root/build/compile-sdl-shape-gate.csh"
hidapi_gate="$root/build/compile-sdl-hidapi-fallback-gate.csh"
public_header_gate="$root/build/check-openstep-public-header-coverage.sh"
public_header_input="$root/build/public-header-audit.c"
final_header_smoke="$root/test/openstep/openstep-sdl-final-archive-public-headers-smoke.c"
final_header_link="$root/test/openstep/link-openstep-sdl-final-archive-public-headers-smoke.csh"
modifier_smoke="$root/test/openstep/openstep-sdl-final-archive-modifier-events-smoke.m"
modifier_link="$root/test/openstep/link-openstep-sdl-final-archive-modifier-events-smoke.csh"
mouse_smoke="$root/test/openstep/openstep-sdl-final-archive-mouse-events-smoke.m"
mouse_link="$root/test/openstep/link-openstep-sdl-final-archive-mouse-events-smoke.csh"
text_smoke="$root/test/openstep/openstep-sdl-final-archive-text-events-smoke.m"
text_link="$root/test/openstep/link-openstep-sdl-final-archive-text-events-smoke.csh"
close_request_smoke="$root/test/openstep/openstep-sdl-final-archive-close-request-smoke.m"
close_request_link="$root/test/openstep/link-openstep-sdl-final-archive-close-request-smoke.csh"
utf8_title_smoke="$root/test/openstep/openstep-sdl-final-archive-utf8-title-smoke.m"
utf8_title_link="$root/test/openstep/link-openstep-sdl-final-archive-utf8-title-smoke.csh"
thread_backend="$root/port/openstep/src/thread/openstep/SDL_systhread.c"
thread_sync_smoke="$root/test/openstep/openstep-sdl-final-archive-thread-sync-smoke.c"
final_runner="$root/../tools/run-openstep-sdl2-final-archive-regression.sh"
release_runner="$root/../tools/rebuild-openstep-sdl2-release-archive.sh"

for file in "$stage" "$closure" "$archive" "$report" "$final_check" "$release_archive" "$bmp_gate" "$shape_gate" "$hidapi_gate" "$public_header_gate" "$public_header_input" "$final_header_smoke" "$final_header_link" "$modifier_smoke" "$modifier_link" "$mouse_smoke" "$mouse_link" "$text_smoke" "$text_link" "$close_request_smoke" "$close_request_link" "$utf8_title_smoke" "$utf8_title_link" "$thread_backend" "$thread_sync_smoke" "$final_runner" "$release_runner"; do
    if [ ! -r "$file" ]; then
        echo "check-openstep-archive-source: missing $file" >&2
        exit 2
    fi
done

require "$stage" 'src/video/SDL_bmp.c'
require "$stage" 'src/video/SDL_shape.c'
require "$stage" 'src/hidapi/SDL_hidapi.c'
require "$stage" 'set stage_root = $work_root/.src-staging'
require "$stage" 'mv $work_root/src $previous_root'
require "$stage" 'mv $stage_root $work_root/src'
require "$bmp_gate" 'SDL_bmp.c'
require "$shape_gate" 'SDL_shape.c'
require "$closure" 'compile-sdl-bmp-gate.csh'
require "$closure" 'SDL-bmp-gate.o'
require "$closure" 'compile-sdl-shape-gate.csh'
require "$closure" 'SDL-shape-gate.o'
require "$closure" 'compile-sdl-hidapi-fallback-gate.csh'
require "$closure" 'SDL-hidapi-fallback-gate.o'
require "$archive" 'libSDL2-diagnostic.a'
require "$archive" 'compile-sdl-bmp-gate.csh'
require "$archive" 'SDL-bmp-gate.o'
require "$archive" 'compile-sdl-shape-gate.csh'
require "$archive" 'SDL-shape-gate.o'
require "$archive" 'compile-sdl-hidapi-fallback-gate.csh'
require "$archive" 'SDL-hidapi-fallback-gate.o'
require "$report" 'NONRELEASE'
require "$final_check" 'short final members'
require "$release_archive" 'check-final-api-manifest.csh'
require "$release_archive" 'ranlib $final'
require "$public_header_gate" 'SDL_main is application-owned'
require "$public_header_input" 'SDL_vulkan.h'
require "$final_header_smoke" 'SDL_GetWindowWMInfo'
require "$final_header_smoke" 'SDL_Vulkan_LoadLibrary'
require "$final_header_link" 'libSDL2.a'
require "$final_runner" 'final-archive-public-headers-smoke'
require "$modifier_smoke" 'keyEventWithType:NSFlagsChanged'
require "$modifier_smoke" 'SDL_SCANCODE_LSHIFT'
require "$modifier_smoke" 'SDL_SCANCODE_LGUI'
require "$modifier_link" 'libSDL2.a'
require "$final_runner" 'final-archive-modifier-events-smoke'
require "$mouse_smoke" 'NSRightMouseDown'
require "$mouse_smoke" 'SDL_BUTTON_RIGHT'
require "$mouse_link" 'libSDL2.a'
require "$final_runner" 'final-archive-mouse-events-smoke'
require "$text_smoke" 'stringWithCharacters'
require "$text_smoke" 'SDL_TEXTINPUT'
require "$text_smoke" 'NSUpArrowFunctionKey'
require "$text_link" 'libSDL2.a'
require "$final_runner" 'final-archive-text-events-smoke'
require "$close_request_smoke" 'performClose:nil'
require "$close_request_smoke" 'SDL_WINDOWEVENT_CLOSE'
require "$close_request_link" 'libSDL2.a'
require "$final_runner" 'final-archive-close-request-smoke'
require "$utf8_title_smoke" 'dataUsingEncoding:NSUTF8StringEncoding'
require "$utf8_title_smoke" 'SDL_SetWindowTitle'
require "$utf8_title_link" 'libSDL2.a'
require "$final_runner" 'final-archive-utf8-title-smoke'
require "$thread_backend" 'cthread_set_name(current, name);'
require "$thread_sync_smoke" 'cthread_name(cthread_self())'
require "$release_runner" 'compile-sdl-blit-core-gate.csh'
require "$release_runner" 'ranlib $target_build/libSDL2.a'

echo "check-openstep-archive-source: PASS staging, closure, diagnostic and final archive wiring"
