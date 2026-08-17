/* Objective-C and SDL2 private-video ABI compile gate for OPENSTEP. */
#import <AppKit/AppKit.h>
#import <AppKit/psopsNeXT.h>

#include "SDL_openstepvideo.h"

int SDL_OpenStepVideoBackendHeaderProbe(void)
{
    SDL_OpenStepVideoData video;
    SDL_OpenStepWindowData window;

    video.application = 0;
    window.window = 0;
    return (sizeof(video) > 0 && sizeof(window) > 0 &&
            sizeof(SDL_VideoDevice) > 0 && sizeof(SDL_Window) > 0) ? 0 : 1;
}
