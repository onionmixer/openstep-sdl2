/* OPENSTEP 4.2 compatibility <stdint.h>.
   Its BSD <sys/types.h> already declares the fixed-width signed intN_t and
   unsigned u_intN_t types used by this SDL2 port; it simply lacks the modern
   header wrapper.  SDL_config_openstep.h supplies the uintN_t aliases. */
#ifndef SDL_OPENSTEP_STDINT_H
#define SDL_OPENSTEP_STDINT_H

#include <sys/types.h>

#endif /* SDL_OPENSTEP_STDINT_H */
