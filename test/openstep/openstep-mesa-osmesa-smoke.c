/* Mesa 3.4.2 OPENSTEP OSMesa smoke: no X11, AppKit or WindowServer needed. */
#include <stdio.h>
#include <string.h>

#include <GL/gl.h>
#include <GL/osmesa.h>

#define TEST_WIDTH 32
#define TEST_HEIGHT 24

int
main(int argc, char **argv)
{
    OSMesaContext context;
    unsigned char pixels[TEST_WIDTH * TEST_HEIGHT * 4];
    const GLubyte *version;

    (void) argc;
    (void) argv;
    memset(pixels, 0, sizeof(pixels));

    context = OSMesaCreateContext(OSMESA_RGBA, NULL);
    if (context == NULL) {
        fprintf(stderr, "OSMesaCreateContext failed\n");
        return 1;
    }
    if (!OSMesaMakeCurrent(context, pixels, GL_UNSIGNED_BYTE,
                           TEST_WIDTH, TEST_HEIGHT)) {
        fprintf(stderr, "OSMesaMakeCurrent failed\n");
        OSMesaDestroyContext(context);
        return 1;
    }

    glViewport(0, 0, TEST_WIDTH, TEST_HEIGHT);
    glClearColor(0.25f, 0.50f, 0.75f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glFinish();
    if (glGetError() != GL_NO_ERROR) {
        fprintf(stderr, "OpenGL clear failed\n");
        OSMesaDestroyContext(context);
        return 1;
    }
    version = glGetString(GL_VERSION);
    if (version == NULL || pixels[0] == 0 || pixels[1] == 0 ||
        pixels[2] == 0 || pixels[3] != 255) {
        fprintf(stderr, "OSMesa buffer or version check failed\n");
        OSMesaDestroyContext(context);
        return 1;
    }

    printf("openstep-mesa-osmesa-smoke: PASS GL_VERSION=%s\n", version);
    OSMesaDestroyContext(context);
    return 0;
}
