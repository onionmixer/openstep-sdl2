#include "SDL.h"
#include "SDL_atomic.h"
#include "SDL_audio.h"
#include "SDL_mutex.h"
#include "SDL_pixels.h"
#include "SDL_rect.h"
#include "SDL_render.h"
#include "SDL_surface.h"
#include "SDL_thread.h"
#include "SDL_internal.h"

static int Matrix3AudioStream(void)
{
    Uint8 source[4];
    Uint8 output[4];
    SDL_AudioStream *stream;

    source[0] = 0x34;
    source[1] = 0x12;
    source[2] = 0x78;
    source[3] = 0x56;
    stream = SDL_NewAudioStream(AUDIO_S16LSB, 1, 22050,
                                AUDIO_S16MSB, 1, 22050);
    if (stream == NULL || SDL_AudioStreamPut(stream, source, 4) != 0 ||
        SDL_AudioStreamFlush(stream) != 0 || SDL_AudioStreamAvailable(stream) != 4 ||
        SDL_AudioStreamGet(stream, output, 4) != 4 ||
        output[0] != 0x12 || output[1] != 0x34 ||
        output[2] != 0x56 || output[3] != 0x78) {
        if (stream) SDL_FreeAudioStream(stream);
        return -1;
    }
    SDL_FreeAudioStream(stream);
    return 0;
}

static int Matrix3AudioLock(void)
{
    SDL_AudioSpec desired;
    SDL_AudioDeviceID device;

    SDL_zero(desired);
    desired.freq = 22050;
    desired.format = AUDIO_S16SYS;
    desired.channels = 1;
    desired.samples = 128;
    device = SDL_OpenAudioDevice(NULL, 0, &desired, NULL, 0);
    if (device == 0) return -1;
    SDL_LockAudioDevice(device);
    SDL_UnlockAudioDevice(device);
    SDL_CloseAudioDevice(device);
    return 0;
}

static int Matrix3Atomic(void)
{
    SDL_atomic_t value;

    SDL_AtomicSet(&value, 1);
    if (SDL_AtomicAdd(&value, 4) != 1 || SDL_AtomicGet(&value) != 5 ||
        SDL_AtomicCAS(&value, 5, 9) != SDL_TRUE || SDL_AtomicGet(&value) != 9) {
        return -1;
    }
    return 0;
}

static int Matrix3Mutex(void)
{
    SDL_mutex *mutex = SDL_CreateMutex();

    if (mutex == NULL || SDL_LockMutex(mutex) != 0 ||
        SDL_LockMutex(mutex) != 0 || SDL_UnlockMutex(mutex) != 0 ||
        SDL_UnlockMutex(mutex) != 0) {
        if (mutex) SDL_DestroyMutex(mutex);
        return -1;
    }
    SDL_DestroyMutex(mutex);
    return 0;
}

static int Matrix3Semaphore(void)
{
    SDL_sem *sem = SDL_CreateSemaphore(0);

    if (sem == NULL || SDL_SemTryWait(sem) != SDL_MUTEX_TIMEDOUT ||
        SDL_SemPost(sem) != 0 || SDL_SemWait(sem) != 0 ||
        SDL_SemValue(sem) != 0) {
        if (sem) SDL_DestroySemaphore(sem);
        return -1;
    }
    SDL_DestroySemaphore(sem);
    return 0;
}

static int Matrix3TLS(void)
{
    SDL_TLSID id;
    int value = 0x4d;

    id = SDL_TLSCreate();
    if (id == 0 || SDL_TLSSet(id, &value, NULL) != 0 || SDL_TLSGet(id) != &value) {
        return -1;
    }
    return 0;
}

static int Matrix3Rect(void)
{
    SDL_Rect a;
    SDL_Rect b;
    SDL_Rect result;
    SDL_Point points[3];

    a.x = 0; a.y = 0; a.w = 2; a.h = 2;
    b.x = 1; b.y = 1; b.w = 2; b.h = 2;
    SDL_UnionRect(&a, &b, &result);
    if (result.x != 0 || result.y != 0 || result.w != 3 || result.h != 3) return -1;
    points[0].x = 0; points[0].y = 0;
    points[1].x = 2; points[1].y = 1;
    points[2].x = 1; points[2].y = 3;
    if (SDL_EnclosePoints(points, 3, NULL, &result) != SDL_TRUE ||
        result.x != 0 || result.y != 0 || result.w != 3 || result.h != 4) return -1;
    return 0;
}

static int Matrix3Surface(void)
{
    SDL_Surface *source;
    SDL_Surface *destination;
    SDL_Rect target;
    Uint32 color;
    Uint32 *pixels;

    source = SDL_CreateRGBSurfaceWithFormat(0, 1, 1, 32, SDL_PIXELFORMAT_ARGB8888);
    destination = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    if (source == NULL || destination == NULL) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return -1;
    }
    color = SDL_MapRGBA(source->format, 0x31, 0x73, 0xb5, 0xff);
    target.x = 0; target.y = 0; target.w = 2; target.h = 2;
    if (SDL_FillRect(source, NULL, color) != 0 ||
        SDL_SetColorKey(source, SDL_TRUE, color) != 0 ||
        SDL_SetColorKey(source, SDL_FALSE, 0) != 0 ||
        SDL_SetSurfaceRLE(source, 1) != 0 ||
        SDL_BlitScaled(source, NULL, destination, &target) != 0) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return -1;
    }
    pixels = (Uint32 *)destination->pixels;
    if (pixels[0] != color || pixels[3] != color) {
        SDL_FreeSurface(source);
        SDL_FreeSurface(destination);
        return -1;
    }
    SDL_FreeSurface(source);
    SDL_FreeSurface(destination);
    return 0;
}

static int Matrix3Renderer(void)
{
    SDL_Surface *surface;
    SDL_Renderer *renderer;
    SDL_Texture *texture;
    SDL_Rect target;
    Uint32 white = 0xffffffff;
    Uint8 r, g, b, a;
    Uint32 *pixels;

    surface = SDL_CreateRGBSurfaceWithFormat(0, 2, 2, 32, SDL_PIXELFORMAT_ARGB8888);
    if (surface == NULL) return -1;
    renderer = SDL_CreateSoftwareRenderer(surface);
    if (renderer == NULL) { SDL_FreeSurface(surface); return -1; }
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                SDL_TEXTUREACCESS_STATIC, 1, 1);
    if (texture == NULL || SDL_UpdateTexture(texture, NULL, &white, (int)sizeof(white)) != 0 ||
        SDL_SetTextureColorMod(texture, 0x80, 0x20, 0x10) != 0 ||
        SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_NONE) != 0) {
        if (texture) SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer); SDL_FreeSurface(surface); return -1;
    }
    target.x = 0; target.y = 0; target.w = 1; target.h = 1;
    if (SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0xff) != 0 ||
        SDL_RenderClear(renderer) != 0 || SDL_RenderCopy(renderer, texture, NULL, &target) != 0 ||
        SDL_RenderFlush(renderer) != 0) {
        SDL_DestroyTexture(texture); SDL_DestroyRenderer(renderer); SDL_FreeSurface(surface); return -1;
    }
    pixels = (Uint32 *)surface->pixels;
    SDL_GetRGBA(pixels[0], surface->format, &r, &g, &b, &a);
    SDL_DestroyTexture(texture); SDL_DestroyRenderer(renderer); SDL_FreeSurface(surface);
    return (r >= 0x7f && r <= 0x80 && g >= 0x1f && g <= 0x20 &&
            b >= 0x0f && b <= 0x10 && a == 0xff) ? 0 : -1;
}

static int Matrix3Stdlib(void)
{
    char short_text[4];
    char *copy;

    if (SDL_utf8strlcpy(short_text, "abcdef", sizeof(short_text)) != 3 ||
        SDL_strcmp(short_text, "abc") != 0) return -1;
    copy = SDL_iconv_string("UTF-8", "UTF-8", "openstep", 9);
    if (copy == NULL || SDL_strcmp(copy, "openstep") != 0) {
        SDL_free(copy);
        return -2;
    }
    SDL_free(copy);
    return 0;
}

int main(void)
{
    const char *driver;
    int stdlib_result;

    SDL_SetMainReady();
    SDL_InitMainThread();
    if (SDL_Init(SDL_INIT_AUDIO) != 0) return 1;
    driver = SDL_GetCurrentAudioDriver();
    if (driver == NULL || SDL_strcmp(driver, "dummy") != 0) { SDL_Quit(); return 2; }
    if (Matrix3AudioStream() != 0) { SDL_Quit(); return 3; }
    if (Matrix3AudioLock() != 0) { SDL_Quit(); return 4; }
    if (Matrix3Atomic() != 0) { SDL_Quit(); return 5; }
    if (Matrix3Mutex() != 0) { SDL_Quit(); return 6; }
    if (Matrix3Semaphore() != 0) { SDL_Quit(); return 7; }
    if (Matrix3TLS() != 0) { SDL_Quit(); return 8; }
    if (Matrix3Rect() != 0) { SDL_Quit(); return 9; }
    if (Matrix3Surface() != 0) { SDL_Quit(); return 10; }
    if (Matrix3Renderer() != 0) { SDL_Quit(); return 11; }
    stdlib_result = Matrix3Stdlib();
    if (stdlib_result != 0) { SDL_Quit(); return stdlib_result == -2 ? 13 : 12; }
    SDL_Quit();
    return 0;
}
