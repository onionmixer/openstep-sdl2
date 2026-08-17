# Release license inventory

This inventory is a release gate, not a substitute for the upstream notices.
The packaging generator must copy the listed original texts into the source
and payload documentation before it invokes the OPENSTEP package utility.

| Package | Component | Required source record | Required payload record | Gate |
| --- | --- | --- | --- | --- |
| SDL2 | SDL 2.32.10 | `upstream/SDL-2.32.10/LICENSE.txt` | `Documentation/OpenStep-SDL2-2.32.10/LICENSE.txt` | byte-for-byte comparison |
| SDL2 | OPENSTEP port changes | `NOTICE_OPENSTEP_PORT.md` | same notice in documentation | names upstream version and marks modified port |
| Mesa | Mesa core and OSMesa | `upstream/Mesa-3.4.2/docs/COPYRIGHT` | `Documentation/OpenStep-Mesa-3.4.2/COPYRIGHT` | byte-for-byte comparison |
| Mesa | Mesa GLU | `upstream/Mesa-3.4.2/docs/COPYING` plus component notice in `COPYRIGHT` | `Documentation/OpenStep-Mesa-3.4.2/COPYING` and `COPYRIGHT` | license text and notice both present |
| Mesa | OPENSTEP port/build changes | `NOTICE_OPENSTEP_PORT.md` | `PORT-NOTES.md` | changes and supported scope identified |

Before the first RC, inspect every installed header/library provenance again.
If a selected header introduces an additional copyright or license notice,
add it to this table and copy the corresponding text.  The Mesa package must
retain the upstream statement that it is not a licensed OpenGL implementation.
