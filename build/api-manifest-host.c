/* Preprocessor-only wrapper: emit target-applicable SDL dynapi symbol names. */
#include "../port/openstep/include/SDL_config_openstep.h"

#define SDL_DYNAPI_PROC(type, name, params, args, rc) SDL_OPENSTEP_API_ ## name
#include "../upstream/SDL-2.32.10/src/dynapi/SDL_dynapi_procs.h"
