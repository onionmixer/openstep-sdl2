/* Create a Workspace-visible logical U+00E9 filename through Foundation.
   Unlike the raw-byte helper, NSData writeToFile: receives an NSString, so
   OPENSTEP applies its documented native filesystem string conversion. */
#import <Foundation/Foundation.h>

#include <stdio.h>

static void PrintBytes(const char *label, NSData *data)
{
    const unsigned char *bytes;
    unsigned int i;

    printf("%s", label);
    if (data != nil) {
        bytes = (const unsigned char *)[data bytes];
        for (i = 0; i < [data length]; ++i) {
            printf(" %02x", (unsigned int)bytes[i]);
        }
    }
    printf("\n");
}

int main(void)
{
    static const char path_utf8[] = "/me/SDL2-logical-\303\251-drop.txt";
    static const char contents[] = "SDL2 OPENSTEP logical UTF-8 filename fixture.\n";
    NSAutoreleasePool *pool;
    NSData *path_data;
    NSString *path;
    NSData *file_data;
    NSData *round_trip;
    BOOL wrote;

    pool = [[NSAutoreleasePool alloc] init];
    path_data = [NSData dataWithBytes:path_utf8 length:sizeof(path_utf8) - 1];
    path = [[NSString alloc] initWithData:path_data encoding:NSUTF8StringEncoding];
    file_data = [NSData dataWithBytes:contents length:sizeof(contents) - 1];
    if (path == nil || file_data == nil) {
        [path release];
        [pool release];
        return 1;
    }
    wrote = [file_data writeToFile:path atomically:NO];
    round_trip = [path dataUsingEncoding:NSUTF8StringEncoding];
    PrintBytes("openstep-create-logical-utf8-fixture: NSString UTF-8 bytes", round_trip);
    [path release];
    [pool release];
    return wrote ? 0 : 2;
}
