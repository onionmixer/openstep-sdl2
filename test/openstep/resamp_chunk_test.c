/* HOST test (not a target program) for candidate c3: SDL 2.32.10's own SDL_ResampleAudio, fed a sine
 * in 1024-frame puts (as water1 does at 49716 Hz) versus one single put.
 * The stream wrapper keeps sample history (left padding) but restarts the
 * output index at 0 every put, so this reproduces exactly that. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
typedef int32_t Sint32; typedef int64_t Sint64;
#define SDL_min(a,b) ((a)<(b)?(a):(b))
#include "/mnt/USERS/onion/DATA_ORIGN/Workspace/NeXT_DRIVER/openstep-sdl20/upstream/SDL-2.32.10/src/audio/SDL_audio_resampler_filter.h"
static Sint32 ResamplerPadding(const Sint32 inrate, const Sint32 outrate)
{
    /* This function uses integer arithmetics to avoid precision loss caused
     * by large floating point numbers. Sint32 is needed for the large number
     * multiplication. The integers are assumed to be non-negative so that
     * division rounds by truncation. */
    if (inrate == outrate) {
        return 0;
    }
    if (inrate > outrate) {
        return (RESAMPLER_SAMPLES_PER_ZERO_CROSSING * inrate + outrate - 1) / outrate;
    }
    return RESAMPLER_SAMPLES_PER_ZERO_CROSSING;
}

/* lpadding and rpadding are expected to be buffers of (ResamplePadding(inrate, outrate) * chans * sizeof(float)) bytes. */
static int SDL_ResampleAudio(const int chans, const int inrate, const int outrate,
                             const float *lpadding, const float *rpadding,
                             const float *inbuf, const int inbuflen,
                             float *outbuf, const int outbuflen)
{
    /* This function uses integer arithmetics to avoid precision loss caused
     * by large floating point numbers. For some operations, Sint32 or Sint64
     * are needed for the large number multiplications. The input integers are
     * assumed to be non-negative so that division rounds by truncation and
     * modulo is always non-negative. Note that the operator order is important
     * for these integer divisions. */
    const int paddinglen = ResamplerPadding(inrate, outrate);
    const int framelen = chans * (int)sizeof(float);
    const int inframes = inbuflen / framelen;
    /* outbuflen isn't total to write, it's total available. */
    const int wantedoutframes = (int)((Sint64)inframes * outrate / inrate);
    const int maxoutframes = outbuflen / framelen;
    const int outframes = SDL_min(wantedoutframes, maxoutframes);
    float *dst = outbuf;
    int i, j, chan;

    for (i = 0; i < outframes; i++) {
        const int srcindex = (int)((Sint64)i * inrate / outrate);
        /* Calculating the following way avoids subtraction or modulo of large
         * floats which have low result precision.
         *   interpolation1
         * = (i / outrate * inrate) - floor(i / outrate * inrate)
         * = mod(i / outrate * inrate, 1)
         * = mod(i * inrate, outrate) / outrate */
        const int srcfraction = ((Sint64)i) * inrate % outrate;
        const float interpolation1 = ((float)srcfraction) / ((float)outrate);
        const int filterindex1 = ((Sint32)srcfraction) * RESAMPLER_SAMPLES_PER_ZERO_CROSSING / outrate;
        const float interpolation2 = 1.0f - interpolation1;
        const int filterindex2 = ((Sint32)(outrate - srcfraction)) * RESAMPLER_SAMPLES_PER_ZERO_CROSSING / outrate;

        for (chan = 0; chan < chans; chan++) {
            float outsample = 0.0f;

            /* do this twice to calculate the sample, once for the "left wing" and then same for the right. */
            for (j = 0; (filterindex1 + (j * RESAMPLER_SAMPLES_PER_ZERO_CROSSING)) < RESAMPLER_FILTER_SIZE; j++) {
                const int filt_ind = filterindex1 + j * RESAMPLER_SAMPLES_PER_ZERO_CROSSING;
                const int srcframe = srcindex - j;
                /* !!! FIXME: we can bubble this conditional out of here by doing a pre loop. */
                const float insample = (srcframe < 0) ? lpadding[((paddinglen + srcframe) * chans) + chan] : inbuf[(srcframe * chans) + chan];
                outsample += (float) (insample * (ResamplerFilter[filt_ind] + (interpolation1 * ResamplerFilterDifference[filt_ind])));
            }

            /* Do the right wing! */
            for (j = 0; (filterindex2 + (j * RESAMPLER_SAMPLES_PER_ZERO_CROSSING)) < RESAMPLER_FILTER_SIZE; j++) {
                const int filt_ind = filterindex2 + j * RESAMPLER_SAMPLES_PER_ZERO_CROSSING;
                const int srcframe = srcindex + 1 + j;
                /* !!! FIXME: we can bubble this conditional out of here by doing a post loop. */
                const float insample = (srcframe >= inframes) ? rpadding[((srcframe - inframes) * chans) + chan] : inbuf[(srcframe * chans) + chan];
                outsample += (float) (insample * (ResamplerFilter[filt_ind] + (interpolation2 * ResamplerFilterDifference[filt_ind])));
            }

            *(dst++) = outsample;
        }
    }

    return outframes * chans * sizeof(float);
}
int main(void)
{
    const int inrate = 49716, outrate = 44100, chans = 2, put = 1024, nputs = 200;
    const int inframes = put * nputs;
    const int pad = ResamplerPadding(inrate, outrate);
    float *in = calloc((inframes + 2*pad) * chans, sizeof(float));
    float *lpad = calloc(pad * chans, sizeof(float));
    float *rpad = calloc(pad * chans, sizeof(float));
    float *one = calloc((inframes * 2) * chans, sizeof(float));
    float *chunked = calloc((inframes * 2) * chans, sizeof(float));
    int i, k, got_one, got_ch = 0;
    for (i = 0; i < inframes; i++) { float v = sinf(2*M_PI*1000.0f*i/inrate); in[i*chans]=v; in[i*chans+1]=v; }
    /* single pass */
    got_one = SDL_ResampleAudio(chans, inrate, outrate, lpad, rpad, in, inframes*chans*sizeof(float), one, inframes*2*chans*sizeof(float)) / (chans*sizeof(float));
    /* chunked, the stream way: left padding = tail of previous put; right padding = start of NEXT put (the stream has it queued) */
    for (k = 0; k < nputs; k++) {
        const float *chunk = in + k*put*chans;
        float *lp = calloc(pad*chans, sizeof(float));
        if (k > 0) memcpy(lp, chunk - pad*chans, pad*chans*sizeof(float));
        const float *rp = (k+1 < nputs) ? chunk + put*chans : rpad;
        int got = SDL_ResampleAudio(chans, inrate, outrate, lp, rp, chunk, put*chans*sizeof(float), chunked + got_ch*chans, (inframes*2 - got_ch)*chans*sizeof(float)) / (chans*sizeof(float));
        got_ch += got; free(lp);
    }
    printf("single pass: %d frames; chunked (%d puts of %d): %d frames; ideal %.3f\n", got_one, nputs, put, got_ch, (double)inframes*outrate/inrate);
    printf("frames lost by chunking: %d (= %.3f per put)\n", got_one - got_ch, (double)(got_one-got_ch)/nputs);
    /* error of the chunked output against the ideal sine at the OUTPUT rate (skip the filter's edges) */
    /* Is the error distortion, or accumulated slip?  Compare each 4410-frame
     * window against the ideal sine allowed to slide by a few frames: if a
     * shift makes the error vanish, the samples are right and only their
     * position is wrong. */
    { int w;
      printf("window   best_shift  rms_at_best\n");
      for (w = 0; w + 4410 < got_ch; w += 22050) {
        double best = 1e9; int bs = 0, sh;
        for (sh = -200; sh <= 200; sh++) {
          double r = 0; int n = 0, i2;
          for (i2 = w; i2 < w + 4410; i2++) { double id = sin(2*M_PI*1000.0*(i2+sh)/outrate);
            double e = chunked[i2*chans] - id; r += e*e; n++; }
          r = sqrt(r/n); if (r < best) { best = r; bs = sh; }
        }
        printf("%6d   %+8d   %10.5f\n", w, bs, best);
      }
    }
    { double rms = 0, mx = 0; int n = 0, bmax = 0;
      for (i = 100; i < got_ch - 100; i++) { double ideal = sin(2*M_PI*1000.0*i/outrate);
        double e = fabs(chunked[i*chans] - ideal); if (e > mx) { mx = e; bmax = i; } rms += e*e; n++; }
      printf("chunked vs ideal 1 kHz sine: rms %.4f, max %.4f at output frame %d (-> %.1f dB max, %.1f dB rms)\n",
             sqrt(rms/n), mx, bmax, 20*log10(mx), 20*log10(sqrt(rms/n)));
    }
    { double rms = 0, mx = 0; int n = 0;
      for (i = 100; i < got_one - 100; i++) { double ideal = sin(2*M_PI*1000.0*i/outrate);
        double e = fabs(one[i*chans] - ideal); if (e > mx) mx = e; rms += e*e; n++; }
      printf("single-pass vs ideal:       rms %.4f, max %.4f (-> %.1f dB max, %.1f dB rms)\n", sqrt(rms/n), mx, 20*log10(mx), 20*log10(sqrt(rms/n)));
    }
    return 0;
}
