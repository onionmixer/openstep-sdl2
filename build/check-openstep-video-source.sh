#!/bin/sh
# Host-side structural gate for the OPENSTEP AppKit video backend. This is not
# a substitute for target Objective-C compilation; it catches an accidental
# loss of standard SDL callback wiring while the target is unavailable.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$script_dir/../port/openstep/src/video/openstep/SDL_openstepvideo.m"

if [ ! -r "$source_file" ]; then
    echo "check-openstep-video-source: missing $source_file" >&2
    exit 2
fi

require() {
    if ! grep -F -q "$1" "$source_file"; then
        echo "check-openstep-video-source: missing required source fragment: $1" >&2
        exit 1
    fi
}

# Native window lifecycle and framebuffer surface path.
require 'device->CreateSDLWindow = OPENSTEP_CreateSDLWindow;'
require 'device->SetWindowTitle = OPENSTEP_SetWindowTitle;'
require 'device->SetWindowIcon = OPENSTEP_SetWindowIcon;'
require 'device->SetWindowFullscreen = OPENSTEP_SetWindowFullscreen;'
require 'device->CreateWindowFramebuffer = OPENSTEP_CreateWindowFramebuffer;'
require 'device->UpdateWindowFramebuffer = OPENSTEP_UpdateWindowFramebuffer;'
require 'device->DestroyWindowFramebuffer = OPENSTEP_DestroyWindowFramebuffer;'

# Display/event/clipboard/drop integration.
require 'device->GetDisplayModes = OPENSTEP_GetDisplayModes;'
require 'display.name = "OPENSTEP Main Display";'
require 'device->PumpEvents = OPENSTEP_PumpEvents;'
require 'device->SetClipboardText = OPENSTEP_SetClipboardText;'
require 'device->AcceptDragAndDrop = OPENSTEP_AcceptDragAndDrop;'
require 'SDL_SendDropFile(_sdl_window, path);'
require 'SDL_SendDropText(_sdl_window, text);'
require 'SDL_SendDropComplete(_sdl_window);'
require 'static SDL_bool OPENSTEP_DropEventsEnabled(void)'
require 'NSStringPboardType'
require 'availableTypeFromArray:'
require 'charactersIgnoringModifiers'
require 'dataUsingEncoding:NSUTF8StringEncoding'
require 'static void OPENSTEP_SendKeyboardText(NSString *characters)'
require 'static SDL_bool OPENSTEP_IsFunctionCharacter(unsigned short character)'
require 'SDL_TEXTINPUT payloads'
require 'static void OPENSTEP_HandleModifierFlags(NSEvent *event)'
require 'title = OPENSTEP_StringFromUTF8(window->title);'
require 'NSAutoreleasePool *pool;'
require 'screen_frame.origin.y + screen_frame.size.height'
require 'mouseLocationOutsideOfEventStream'
require 'A button event delivered to this content view is authoritative mouse'
require 'Do not erase focus newly assigned by another native SDL window'
require 'addTrackingRect:[self bounds] owner:self'
require 'mouseEntered:(NSEvent *)event'
require 'mouseExited:(NSEvent *)event'
require 'installMouseTrackingRect'
require 'SDL_SCANCODE_LSHIFT'
require 'SDL_SCANCODE_LCTRL'
require 'SDL_SCANCODE_LALT'
require 'SDL_SCANCODE_LGUI'
require 'windowShouldClose:'
require 'return NO;'
require 'Refresh the ordinary SDL mouse state when AppKit gives this SDL'

if grep -F -q 'PScurrentmouse(' "$source_file"; then
    echo "check-openstep-video-source: PScurrentmouse is not AppKit-safe" >&2
    exit 1
fi

# Compatibility OpenGL 1.2 path and standard message boxes.
require 'device->GL_CreateContext = OPENSTEP_GL_CreateContext;'
require 'device->GL_SwapWindow = OPENSTEP_GL_SwapWindow;'
require 'device->ShowMessageBox = OPENSTEP_ShowMessageBox;'
require 'OPENSTEP_ShowMessageBoxBootstrap'

echo "check-openstep-video-source: PASS standard AppKit callback wiring"
