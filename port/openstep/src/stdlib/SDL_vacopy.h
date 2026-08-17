/* OPENSTEP 4.2 / GCC 2.7 has no __va_copy builtin. The target-side
   va-copy-smoke.c compilation proves that its va_list is assignable. */
#ifndef SDL_openstep_vacopy_h_
#define SDL_openstep_vacopy_h_

#undef va_copy
#define va_copy(dst, src) ((dst) = (src))

#endif

