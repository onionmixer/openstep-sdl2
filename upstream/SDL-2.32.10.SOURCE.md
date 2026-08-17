# SDL 2.32.10 pristine-source record

`SDL-2.32.10/`, when imported, is an unmodified upstream source tree. Do not
edit it for the OPENSTEP port. Keep all target changes below
`port/openstep/`, and retain each bootstrap change as a reviewed patch.

| Item | Value |
|---|---|
| Project | Simple DirectMedia Layer 2 |
| selected release tag | `release-2.32.10` |
| commit | `5d249570393f7a37e037abf22cd6012a4cc56a71` |
| Git tree | `c2fd07672476c3945f498479938743c616ff44e5` |
| upstream repository | `https://github.com/libsdl-org/SDL.git` |
| tag commit date | 2025-09-01 |
| licence | zlib (`SDL-2.32.10/LICENSE.txt`) |

Reproducible import procedure after the staging prerequisite is available:

```sh
git clone --branch release-2.32.10 --depth 1 https://github.com/libsdl-org/SDL.git SDL-2.32.10
git -C SDL-2.32.10 rev-parse HEAD
git -C SDL-2.32.10 rev-parse HEAD^{tree}
```

Both revisions equal the values in this record. The pristine source is now
imported in this directory from that exact Git tree and was staged to the
OPENSTEP target on 2026-08-15. It remains source provenance, not evidence
that the SDL2 library has built or run.
