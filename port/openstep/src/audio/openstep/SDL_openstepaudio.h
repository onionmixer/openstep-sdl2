#ifndef SDL_openstepaudio_h_
#define SDL_openstepaudio_h_

#include "../SDL_sysaudio.h"

/* SDL_sysaudio.h undefines this after declaring SDL_AudioDevice. Backend
   callbacks use the same conventional shorthand as upstream drivers. */
#define _THIS SDL_AudioDevice *_this

#define OPENSTEP_AUDIO_QUEUE_SLOTS 8
/* Three, not four: the worst-phase reserve is (AHEAD - 1) buffers, and at
 * freq/8 that is 250 ms -- enough for a frame-long SDL_LockAudio -- while
 * the nominal queue drops from a second to ~375 ms. */
#define OPENSTEP_AUDIO_QUEUE_AHEAD 3

struct SDL_PrivateAudioData
{
    Uint8 *mixbuf;
    Uint32 mixlen;
    Uint32 delay_ms;
    int started;
    int underruns;
    int playfailures;
    void *sounds[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int tags[OPENSTEP_AUDIO_QUEUE_SLOTS];
    int next_tag;
    int head;
    int count;
};

#endif
