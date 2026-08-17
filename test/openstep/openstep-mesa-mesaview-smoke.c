/* Execute Mesa 3.4.2's unmodified OpenStep/MesaView renderer headlessly. */
#include <stdio.h>
#include <string.h>

#include <GL/gl.h>
#include <GL/osmesa.h>

#include "mesadraw.h"

#define TEST_WIDTH 128
#define TEST_HEIGHT 96

int
main(int argc, char **argv)
{
    OSMesaContext context;
    unsigned char pixels[TEST_WIDTH * TEST_HEIGHT * 4];
    int index;
    int nonzero;

    (void)argc;
    (void)argv;
    memset(pixels, 0, sizeof(pixels));
    context = OSMesaCreateContext(OSMESA_ARGB, NULL);
    if (!context || !OSMesaMakeCurrent(context, pixels, GL_UNSIGNED_BYTE,
                                       TEST_WIDTH, TEST_HEIGHT)) {
        fprintf(stderr, "MesaView OSMesa setup failed\n");
        return 1;
    }
    OSMesaPixelStore(OSMESA_Y_UP, 0);
    make_matrix();
    my_init((float)TEST_WIDTH, (float)TEST_HEIGHT);
    set_viewpoint(130.0f, 30.0f, 0.0f);
    draw_scene(1, 1, 0);
    glFinish();
    if (glGetError() != GL_NO_ERROR) {
        fprintf(stderr, "MesaView renderer reported an OpenGL error\n");
        OSMesaDestroyContext(context);
        return 1;
    }
    nonzero = 0;
    for (index = 0; index < (int)sizeof(pixels); ++index) {
        if (pixels[index] != 0) ++nonzero;
    }
    if (nonzero == 0) {
        fprintf(stderr, "MesaView renderer produced an empty buffer\n");
        OSMesaDestroyContext(context);
        return 1;
    }
    OSMesaDestroyContext(context);
    printf("openstep-mesa-mesaview-smoke: PASS nonzero=%d\n", nonzero);
    return 0;
}
