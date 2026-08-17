# Linking

Install `OpenStepSDL2Libraries.pkg` and `OpenStepSDL2Headers.pkg` at the same
prefix, then compile with `-I<Prefix>/Headers` and link
`<Prefix>/Libraries/libSDL2.a` plus OPENSTEP frameworks required by the
application: `-framework AppKit -framework Foundation -framework SoundKit`.
OpenGL clients additionally install the Mesa Libraries and Headers packages at
that prefix and link `-L<Prefix>/Libraries -lGL -lm`.
