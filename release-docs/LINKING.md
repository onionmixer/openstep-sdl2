# Linking

Compile with `-I<Prefix>/Headers` and link `<Prefix>/Libraries/libSDL2.a` plus
OPENSTEP frameworks required by the application: `-framework AppKit -framework
Foundation -framework SoundKit`. OpenGL clients additionally link the separate
Mesa package with `-L<Prefix>/Libraries -lGL -lm`.
