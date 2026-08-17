#include "SDL.h"
#include "SDL_render.h"
#include "SDL_surface.h"
#include "SDL_internal.h"

int main(void)
{
    SDL_Surface *surface;
    SDL_Renderer *renderer;
    SDL_Texture *texture;
    SDL_Texture *target_texture;
    SDL_Texture *stream_texture;
    SDL_RendererInfo info;
    Uint32 clear_color;
    Uint32 point_color;
    Uint32 texture_color;
    Uint32 target_color;
    Uint32 stream_color;
    Uint32 *pixels;
    SDL_Rect texture_destination;
    SDL_Rect target_destination;
    SDL_Rect stream_destination;
    SDL_Rect rotate_destination;
    SDL_Vertex geometry[6];
    Uint8 r;
    Uint8 g;
    Uint8 b;
    Uint8 a;
    void *stream_pixels;
    int stream_pitch;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(0) != 0) {
        return 1;
    }
    surface = SDL_CreateRGBSurfaceWithFormat(0, 6, 4, 32,
                                             SDL_PIXELFORMAT_ARGB8888);
    if (surface == NULL) {
        SDL_Quit();
        return 2;
    }
    renderer = SDL_CreateSoftwareRenderer(surface);
    if (renderer == NULL) {
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 3;
    }
    if (SDL_GetRendererInfo(renderer, &info) != 0 || info.name == NULL) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 4;
    }

    clear_color = SDL_MapRGBA(surface->format, 0x11, 0x22, 0x33, 0xff);
    point_color = SDL_MapRGBA(surface->format, 0xaa, 0xbb, 0xcc, 0xff);
    texture_color = SDL_MapRGBA(surface->format, 0x44, 0x55, 0x66, 0xff);
    target_color = SDL_MapRGBA(surface->format, 0x20, 0x40, 0x60, 0xff);
    stream_color = SDL_MapRGBA(surface->format, 0x90, 0xa0, 0xb0, 0xff);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STATIC, 1, 1);
    if (texture == NULL) {
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 5;
    }
    target_texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                       SDL_TEXTUREACCESS_TARGET, 1, 1);
    if (target_texture == NULL) {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 6;
    }
    stream_texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                       SDL_TEXTUREACCESS_STREAMING, 1, 1);
    if (stream_texture == NULL) {
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 7;
    }
    texture_destination.x = 3;
    texture_destination.y = 3;
    texture_destination.w = 1;
    texture_destination.h = 1;
    target_destination.x = 3;
    target_destination.y = 2;
    target_destination.w = 1;
    target_destination.h = 1;
    stream_destination.x = 3;
    stream_destination.y = 1;
    stream_destination.w = 1;
    stream_destination.h = 1;
    rotate_destination.x = 4;
    rotate_destination.y = 0;
    rotate_destination.w = 1;
    rotate_destination.h = 1;
    geometry[0].position.x = 0.0f;
    geometry[0].position.y = 0.0f;
    geometry[1].position.x = 3.0f;
    geometry[1].position.y = 0.0f;
    geometry[2].position.x = 0.0f;
    geometry[2].position.y = 3.0f;
    geometry[3].position = geometry[1].position;
    geometry[4].position.x = 3.0f;
    geometry[4].position.y = 3.0f;
    geometry[5].position = geometry[2].position;
    geometry[0].color.r = 0x77;
    geometry[0].color.g = 0x88;
    geometry[0].color.b = 0x99;
    geometry[0].color.a = 0xff;
    geometry[1].color = geometry[0].color;
    geometry[2].color = geometry[0].color;
    geometry[3].color = geometry[0].color;
    geometry[4].color = geometry[0].color;
    geometry[5].color = geometry[0].color;
    geometry[0].tex_coord.x = 0.0f;
    geometry[0].tex_coord.y = 0.0f;
    geometry[1].tex_coord = geometry[0].tex_coord;
    geometry[2].tex_coord = geometry[0].tex_coord;
    geometry[3].tex_coord = geometry[0].tex_coord;
    geometry[4].tex_coord = geometry[0].tex_coord;
    geometry[5].tex_coord = geometry[0].tex_coord;
    if (SDL_LockTexture(stream_texture, NULL, &stream_pixels, &stream_pitch) != 0) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 8;
    }
    if (stream_pitch < (int)sizeof(Uint32)) {
        SDL_UnlockTexture(stream_texture);
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 9;
    }
    *(Uint32 *)stream_pixels = stream_color;
    SDL_UnlockTexture(stream_texture);
    if (SDL_SetRenderTarget(renderer, target_texture) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0x20, 0x40, 0x60, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 ||
        SDL_SetRenderTarget(renderer, NULL) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0x11, 0x22, 0x33, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 ||
        SDL_SetRenderDrawColor(renderer, 0xaa, 0xbb, 0xcc, 0xff) != 0 ||
        SDL_RenderDrawPoint(renderer, 1, 3) != 0 ||
        SDL_UpdateTexture(texture, NULL, &texture_color, (int)sizeof(texture_color)) != 0 ||
        SDL_RenderCopy(renderer, texture, NULL, &texture_destination) != 0 ||
        SDL_RenderCopyEx(renderer, texture, NULL, &rotate_destination, 90.0,
                         NULL, SDL_FLIP_NONE) != 0 ||
        SDL_RenderCopy(renderer, target_texture, NULL, &target_destination) != 0 ||
        SDL_RenderCopy(renderer, stream_texture, NULL, &stream_destination) != 0 ||
        SDL_RenderGeometry(renderer, NULL, geometry, 6, NULL, 0) != 0 ||
        SDL_RenderFlush(renderer) != 0) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 10;
    }
    pixels = (Uint32 *)surface->pixels;
    if (pixels[3] != clear_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 11;
    }
    SDL_GetRGBA(pixels[(surface->pitch / (int)sizeof(Uint32)) + 1], surface->format,
                &r, &g, &b, &a);
    if (r < 0x60 || g < 0x70 || b < 0x80 || a != 0xff) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 12;
    }
    if (pixels[3 * (surface->pitch / (int)sizeof(Uint32)) + 1] != point_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 13;
    }
    if (pixels[3 * (surface->pitch / (int)sizeof(Uint32)) + 3] != texture_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 14;
    }
    if (pixels[4] != texture_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 15;
    }
    if (pixels[2 * (surface->pitch / (int)sizeof(Uint32)) + 3] != target_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 16;
    }
    if (pixels[(surface->pitch / (int)sizeof(Uint32)) + 3] != stream_color) {
        SDL_DestroyTexture(stream_texture);
        SDL_DestroyTexture(target_texture);
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_FreeSurface(surface);
        SDL_Quit();
        return 17;
    }

    /* This software-only renderer has no SDL_Window. RenderPresent therefore
       has no display side effect, but must still safely flush its queue. */
    SDL_RenderPresent(renderer);
    SDL_DestroyTexture(stream_texture);
    SDL_DestroyTexture(target_texture);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_FreeSurface(surface);
    SDL_Quit();
    return 0;
}
