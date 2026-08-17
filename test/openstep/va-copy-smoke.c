#include <stdarg.h>

static int consume_arguments(const char *first, ...)
{
    va_list source;
    va_list copy;

    va_start(source, first);
    copy = source;
    va_end(copy);
    va_end(source);
    return 0;
}

int main(void)
{
    return consume_arguments("openstep", 1);
}

