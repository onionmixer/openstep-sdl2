/*
 * Handing SDL2 a faster way to put a GL frame on the screen.
 *
 * WHY THIS IS A CALLBACK STRUCT AND NOT A CALL.  On this system an
 * accelerated Mesa can draw into video memory, and delivering such a frame
 * the ordinary way means reading it back into system memory first -- which
 * was measured at 746 ns a pixel and, for one spinning teapot at 320x240,
 * accounted for 99.9% of a frame.  The accelerated Mesa can instead ask its
 * kernel driver to copy video memory to the screen directly, and that took
 * the same demo from 0.54 to 87.53 frames a second.
 *
 * But libSDL2.a must keep linking against a STOCK Mesa, where none of those
 * functions exist.  So SDL cannot name them.  The application -- which knows
 * which library it linked -- hands them over instead:
 *
 *     static const SDL_OpenStepGLPresent hooks = {
 *         SDL_OPENSTEP_GLPRESENT_ABI, sizeof(hooks),
 *         OSMGAMesaBufferOrigin,
 *         OSMGAMesaBufferPresentMode,
 *         OSMGAMesaBufferPresentRect
 *     };
 *     SDL_SetWindowData(window, SDL_OPENSTEP_GLPRESENT_KEY, (void *)&hooks);
 *
 * and SDL calls plain function pointers.  A program that registers nothing
 * behaves exactly as it does today, which is what a stock-Mesa build must
 * do -- and stock Mesa is not slow here: it renders straight into the
 * caller's array, so there is no readback to remove.
 *
 * THE STRUCT MUST OUTLIVE THE REGISTRATION.  SDL keeps the pointer, not a
 * copy, until the same key is set to NULL and no further swap uses it.  A
 * struct on the stack is a bug this contract cannot catch for you.
 *
 * WHAT REGISTERING MEANS, beyond speed: the stamp goes onto the screen
 * behind the window server's back.  The caller's array becomes stale, and
 * SDL owns a screen rectangle rather than compositing into a window.  That
 * is why this is opt-in and can never be inferred.
 */
#ifndef SDL_openstepglpresent_h_
#define SDL_openstepglpresent_h_

#define SDL_OPENSTEP_GLPRESENT_KEY "OpenStep.GL.VRAMPresent"
#define SDL_OPENSTEP_GLPRESENT_ABI 1UL

typedef struct
{
    /*
     * Both come first and both are checked.  The version alone is not
     * enough: a struct that grows leaves an older registration shorter than
     * SDL believes, and reading past it is exactly the sort of failure that
     * shows up as something else entirely.  Every field below is used only
     * after its end is confirmed to lie within size.
     */
    unsigned long abi;
    unsigned long size;

    /*
     * Where the surface being drawn into lives.  Zero means the caller's
     * own memory, so there is nothing in video memory to stamp; non-zero is
     * the surface's origin.  SDL uses it only as a yes/no.
     *
     * It returns unsigned long rather than a truth value because that is
     * what the driver's own function returns, and a contract that made the
     * application cast its function pointers would be a contract that hid
     * a signature mismatch behind the cast.
     */
    unsigned long (*surface_origin)(void);

    /* 1 declares the caller's array stale and stands the readback down;
       0 gives it back and leaves the array refreshed. */
    void (*set_present_mode)(int on);

    /* Copy a rectangle of the surface to (dstX, dstY) on the visible
       screen.  Returns 0 on success; on refusal the driver's verdict is
       written through outVerdict. */
    int (*present_rect)(unsigned long srcX, unsigned long srcY,
                        unsigned long w, unsigned long h,
                        long dstX, long dstY,
                        unsigned long *outVerdict);
} SDL_OpenStepGLPresent;

#endif /* SDL_openstepglpresent_h_ */
