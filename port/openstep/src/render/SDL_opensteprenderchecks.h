#ifndef SDL_opensteprenderchecks_h_
#define SDL_opensteprenderchecks_h_

/* GCC 2.7 cannot pass an empty second macro argument through SDL_render.c's
   nested validation macros. These helpers preserve the same invalid-object
   error and void-return behavior at the affected call sites. This header is
   included only by the private OPENSTEP build overlay after the renderer's
   magic objects are declared. */
static int SDL_OpenStepRendererMagicValidAllowDestroyed(SDL_Renderer *renderer)
{
    if ((renderer == NULL) || (renderer->magic != &renderer_magic)) {
        SDL_InvalidParamError("renderer");
        return 0;
    }
    return 1;
}

static int SDL_OpenStepRendererMagicValid(SDL_Renderer *renderer)
{
    if (SDL_OpenStepRendererMagicValidAllowDestroyed(renderer) == 0) {
        return 0;
    }
    if (renderer->destroyed) {
        SDL_SetError("Renderer window has been destroyed");
        return 0;
    }
    return 1;
}

static int SDL_OpenStepTextureMagicValid(SDL_Texture *texture)
{
    if ((texture == NULL) || (texture->magic != &texture_magic)) {
        SDL_InvalidParamError("texture");
        return 0;
    }
    return 1;
}

#endif
