/* Standard SDL2 software-renderer-to-native-window smoke for OPENSTEP. */
#include <stdio.h>

#include "SDL.h"

static int
fail(const char *what)
{
    fprintf(stderr, "openstep-sdl-window-renderer-smoke: %s: %s\n", what, SDL_GetError());
    return 1;
}

int
main(int argc, char **argv)
{
    SDL_Window *window;
    SDL_Renderer *renderer;
    SDL_Texture *texture;
    SDL_Texture *target_texture;
    SDL_RendererInfo info;
    SDL_PixelFormat *format;
    SDL_Rect sample;
    SDL_Rect texture_destination;
    SDL_Rect texture_sample;
    SDL_Vertex triangle[3];
    Uint32 pixel;
    Uint32 texture_pixels[4];
    Uint8 red, green, blue, alpha;
    int output_w, output_h;

    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return fail("video init failed");
    window = SDL_CreateWindow("SDL OpenStep renderer smoke", 40, 160, 96, 72, 0);
    if (!window) {
        SDL_Quit();
        return fail("window creation failed");
    }
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (!renderer) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_CreateRenderer failed");
    }
    if (SDL_GetRendererInfo(renderer, &info) != 0 || !info.name ||
        SDL_strcmp(info.name, "software") != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("unexpected renderer driver");
    }
    if (SDL_SetRenderDrawColor(renderer, 0x31, 0x73, 0xb5, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("clear failed");
    }
    sample.x = 4;
    sample.y = 5;
    sample.w = 1;
    sample.h = 1;
    if (SDL_RenderReadPixels(renderer, &sample, SDL_PIXELFORMAT_ARGB8888,
                             &pixel, (int)sizeof(pixel)) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_RenderReadPixels failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red != 0x31 || green != 0x73 || blue != 0xb5 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: readback %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_RenderPresent(renderer);
    texture_pixels[0] = 0xffd04020;
    texture_pixels[1] = 0xff2070d0;
    texture_pixels[2] = 0xff30b060;
    texture_pixels[3] = 0xffe0c020;
    texture_destination.x = 10;
    texture_destination.y = 12;
    texture_destination.w = 2;
    texture_destination.h = 2;
    texture_sample.x = 10;
    texture_sample.y = 12;
    texture_sample.w = 1;
    texture_sample.h = 1;
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STATIC, 2, 2);
    if (!texture ||
        SDL_UpdateTexture(texture, NULL, texture_pixels, 2 * (int)sizeof(Uint32)) != 0 ||
        SDL_RenderCopy(renderer, texture, NULL, &texture_destination) != 0 ||
        SDL_RenderReadPixels(renderer, &texture_sample,
                             SDL_PIXELFORMAT_ARGB8888, &pixel, (int)sizeof(pixel)) != 0) {
        if (texture) SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("texture upload/copy/readback failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("texture pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red != 0xd0 || green != 0x40 || blue != 0x20 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: texture readback %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    texture_destination.x = 20;
    texture_destination.y = 12;
    if (SDL_RenderCopyEx(renderer, texture, NULL, &texture_destination, 180.0,
                         NULL, SDL_FLIP_NONE) != 0) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("SDL_RenderCopyEx failed");
    }
    texture_sample.x = 20;
    texture_sample.y = 12;
    if (SDL_RenderReadPixels(renderer, &texture_sample,
                             SDL_PIXELFORMAT_ARGB8888, &pixel,
                             (int)sizeof(pixel)) != 0) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("rotated texture readback failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("rotated texture pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red != 0xe0 || green != 0xc0 || blue != 0x20 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: rotated texture %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    if (SDL_SetRenderDrawColor(renderer, 0x20, 0x40, 0x60, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("blend background clear failed");
    }
    texture_pixels[0] = 0x80e02010;
    texture_pixels[1] = texture_pixels[0];
    texture_pixels[2] = texture_pixels[0];
    texture_pixels[3] = texture_pixels[0];
    texture_destination.x = 30;
    texture_destination.y = 12;
    texture_destination.w = 1;
    texture_destination.h = 1;
    texture_sample.x = 30;
    texture_sample.y = 12;
    texture_sample.w = 1;
    texture_sample.h = 1;
    if (SDL_UpdateTexture(texture, NULL, texture_pixels, 2 * (int)sizeof(Uint32)) != 0 ||
        SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND) != 0 ||
        SDL_RenderCopy(renderer, texture, NULL, &texture_destination) != 0 ||
        SDL_RenderReadPixels(renderer, &texture_sample,
                             SDL_PIXELFORMAT_ARGB8888, &pixel,
                             (int)sizeof(pixel)) != 0) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("texture blend/readback failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("blend pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red < 127 || red > 129 || green < 47 || green > 49 ||
        blue < 55 || blue > 57 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: blend %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    target_texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                       SDL_TEXTUREACCESS_TARGET, 2, 2);
    if (!target_texture || SDL_SetRenderTarget(renderer, target_texture) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0x18, 0xa8, 0x58, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 || SDL_SetRenderTarget(renderer, NULL) != 0) {
        if (target_texture) SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("render target setup failed");
    }
    texture_destination.x = 40;
    texture_destination.y = 12;
    texture_destination.w = 2;
    texture_destination.h = 2;
    texture_sample.x = 40;
    texture_sample.y = 12;
    texture_sample.w = 1;
    texture_sample.h = 1;
    if (SDL_RenderCopy(renderer, target_texture, NULL, &texture_destination) != 0 ||
        SDL_RenderReadPixels(renderer, &texture_sample,
                             SDL_PIXELFORMAT_ARGB8888, &pixel,
                             (int)sizeof(pixel)) != 0) {
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("render target copy/readback failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("render target pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red != 0x18 || green != 0xa8 || blue != 0x58 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: render target %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_DestroyTexture(target_texture);
    triangle[0].position.x = 50.0f;
    triangle[0].position.y = 12.0f;
    triangle[1].position.x = 54.0f;
    triangle[1].position.y = 12.0f;
    triangle[2].position.x = 50.0f;
    triangle[2].position.y = 16.0f;
    triangle[0].color.r = 0x7a;
    triangle[0].color.g = 0x24;
    triangle[0].color.b = 0xc8;
    triangle[0].color.a = 0xff;
    triangle[1].color = triangle[0].color;
    triangle[2].color = triangle[0].color;
    triangle[0].tex_coord.x = 0.0f;
    triangle[0].tex_coord.y = 0.0f;
    triangle[1].tex_coord = triangle[0].tex_coord;
    triangle[2].tex_coord = triangle[0].tex_coord;
    texture_sample.x = 51;
    texture_sample.y = 13;
    texture_sample.w = 1;
    texture_sample.h = 1;
    if (SDL_RenderGeometry(renderer, NULL, triangle, 3, NULL, 0) != 0 ||
        SDL_RenderReadPixels(renderer, &texture_sample,
                             SDL_PIXELFORMAT_ARGB8888, &pixel,
                             (int)sizeof(pixel)) != 0) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("geometry/readback failed");
    }
    format = SDL_AllocFormat(SDL_PIXELFORMAT_ARGB8888);
    if (!format) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("geometry pixel format allocation failed");
    }
    SDL_GetRGBA(pixel, format, &red, &green, &blue, &alpha);
    SDL_FreeFormat(format);
    if (red != 0x7a || green != 0x24 || blue != 0xc8 || alpha != 0xff) {
        fprintf(stderr, "openstep-sdl-window-renderer-smoke: geometry %u,%u,%u,%u\n",
                (unsigned int)red, (unsigned int)green,
                (unsigned int)blue, (unsigned int)alpha);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }
    SDL_RenderPresent(renderer);
    SDL_DestroyTexture(texture);
    SDL_SetWindowSize(window, 120, 90);
    SDL_Delay(20);
    SDL_PumpEvents();
    if (SDL_GetRendererOutputSize(renderer, &output_w, &output_h) != 0 ||
        output_w != 120 || output_h != 90 ||
        SDL_SetRenderDrawColor(renderer, 0x9a, 0x51, 0x17, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return fail("resize surface reacquisition failed");
    }
    SDL_RenderPresent(renderer);
    SDL_PumpEvents();
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    printf("openstep-sdl-window-renderer-smoke: PASS software+texture+copyex+blend+target+geometry+readback+present+resize\n");
    return 0;
}
