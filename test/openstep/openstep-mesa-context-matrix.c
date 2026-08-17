/* Mesa 3.4.2 context/proc/resize matrix used by the SDL OpenStep GL driver.
   No X11, AppKit or WindowServer API is used here. */
#include <stdio.h>
#include <string.h>

#include <GL/gl.h>
#include <GL/osmesa.h>

extern const GLvoid *_glapi_get_proc_address(const char *funcName);
extern void gl_make_current(void *ctx, void *buffer);

#define WIDTH_A 32
#define HEIGHT_A 24
#define WIDTH_B 48
#define HEIGHT_B 40

typedef void (GLAPIENTRY *ClearColorProc)(GLclampf, GLclampf, GLclampf, GLclampf);
typedef void (GLAPIENTRY *ClearProc)(GLbitfield);
typedef GLenum (GLAPIENTRY *GetErrorProc)(void);
typedef const GLubyte *(GLAPIENTRY *GetStringProc)(GLenum);
typedef void (GLAPIENTRY *GenTexturesProc)(GLsizei, GLuint *);
typedef void (GLAPIENTRY *BindTextureProc)(GLenum, GLuint);
typedef GLboolean (GLAPIENTRY *IsTextureProc)(GLuint);
typedef void (GLAPIENTRY *BeginProc)(GLenum);
typedef void (GLAPIENTRY *Color3fProc)(GLfloat, GLfloat, GLfloat);
typedef void (GLAPIENTRY *Vertex2fProc)(GLfloat, GLfloat);
typedef void (GLAPIENTRY *EndProc)(void);

int
main(int argc, char **argv)
{
    OSMesaContext first;
    OSMesaContext second;
    unsigned char first_pixels[WIDTH_A * HEIGHT_A * 4];
    unsigned char second_pixels[WIDTH_B * HEIGHT_B * 4];
    ClearColorProc clear_color;
    ClearProc clear;
    GetErrorProc get_error;
    GetStringProc get_string;
    GenTexturesProc gen_textures;
    BindTextureProc bind_texture;
    IsTextureProc is_texture;
    BeginProc begin;
    Color3fProc color3f;
    Vertex2fProc vertex2f;
    EndProc end;
    const GLubyte *version;
    GLuint texture;
    GLint width;
    GLint height;

    (void)argc;
    (void)argv;
    memset(first_pixels, 0, sizeof(first_pixels));
    memset(second_pixels, 0, sizeof(second_pixels));

    first = OSMesaCreateContext(OSMESA_ARGB, NULL);
    if (!first || !OSMesaMakeCurrent(first, first_pixels, GL_UNSIGNED_BYTE,
                                     WIDTH_A, HEIGHT_A)) {
        fprintf(stderr, "first OSMesa context failed\n");
        return 1;
    }
    OSMesaPixelStore(OSMESA_Y_UP, 0);
    clear_color = (ClearColorProc)_glapi_get_proc_address("glClearColor");
    clear = (ClearProc)_glapi_get_proc_address("glClear");
    get_error = (GetErrorProc)_glapi_get_proc_address("glGetError");
    get_string = (GetStringProc)_glapi_get_proc_address("glGetString");
    gen_textures = (GenTexturesProc)_glapi_get_proc_address("glGenTextures");
    bind_texture = (BindTextureProc)_glapi_get_proc_address("glBindTexture");
    is_texture = (IsTextureProc)_glapi_get_proc_address("glIsTexture");
    begin = (BeginProc)_glapi_get_proc_address("glBegin");
    color3f = (Color3fProc)_glapi_get_proc_address("glColor3f");
    vertex2f = (Vertex2fProc)_glapi_get_proc_address("glVertex2f");
    end = (EndProc)_glapi_get_proc_address("glEnd");
    if (!clear_color || !clear || !get_error || !get_string || !gen_textures ||
        !bind_texture || !is_texture || !begin || !color3f || !vertex2f || !end) {
        fprintf(stderr, "Mesa GL entry-point resolver failed\n");
        OSMesaDestroyContext(first);
        return 1;
    }

    clear_color(0.0f, 0.0f, 0.0f, 1.0f);
    clear(GL_COLOR_BUFFER_BIT);
    begin(GL_TRIANGLES);
    color3f(1.0f, 0.0f, 0.0f);
    vertex2f(-0.75f, -0.75f);
    vertex2f(0.75f, -0.75f);
    vertex2f(0.0f, 0.75f);
    end();
    glFinish();
    version = get_string(GL_VERSION);
    if (get_error() != GL_NO_ERROR ||
        first_pixels[((HEIGHT_A / 2) * WIDTH_A + (WIDTH_A / 2)) * 4] != 0 ||
        first_pixels[((HEIGHT_A / 2) * WIDTH_A + (WIDTH_A / 2)) * 4 + 1] != 0 ||
        first_pixels[((HEIGHT_A / 2) * WIDTH_A + (WIDTH_A / 2)) * 4 + 2] == 0 ||
        first_pixels[((HEIGHT_A / 2) * WIDTH_A + (WIDTH_A / 2)) * 4 + 3] != 255 ||
        !version) {
        fprintf(stderr, "first context rendering failed\n");
        OSMesaDestroyContext(first);
        return 1;
    }
    gen_textures(1, &texture);
    bind_texture(GL_TEXTURE_2D, texture);

    second = OSMesaCreateContext(OSMESA_ARGB, first);
    if (!second || !OSMesaMakeCurrent(second, second_pixels, GL_UNSIGNED_BYTE,
                                      WIDTH_B, HEIGHT_B)) {
        fprintf(stderr, "shared OSMesa context failed\n");
        OSMesaDestroyContext(first);
        return 1;
    }
    OSMesaPixelStore(OSMESA_Y_UP, 0);
    if (!is_texture(texture)) {
        fprintf(stderr, "shared texture state failed\n");
        OSMesaDestroyContext(second);
        OSMesaDestroyContext(first);
        return 1;
    }
    OSMesaGetIntegerv(OSMESA_WIDTH, &width);
    OSMesaGetIntegerv(OSMESA_HEIGHT, &height);
    if (width != WIDTH_B || height != HEIGHT_B) {
        fprintf(stderr, "resized context dimensions failed\n");
        OSMesaDestroyContext(second);
        OSMesaDestroyContext(first);
        return 1;
    }
    gl_make_current(NULL, NULL);
    if (OSMesaGetCurrentContext() != NULL) {
        fprintf(stderr, "context detach failed\n");
        OSMesaDestroyContext(second);
        OSMesaDestroyContext(first);
        return 1;
    }

    OSMesaDestroyContext(second);
    OSMesaDestroyContext(first);
    printf("openstep-mesa-context-matrix: PASS GL_VERSION=%s\n",
           (const char *)version);
    return 0;
}
