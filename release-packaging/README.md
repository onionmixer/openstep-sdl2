# Release packaging workspace

This directory is the P0 source of truth for splitting the completed work
into six OPENSTEP Developer-style Installer packages: Libraries, Headers and
Demos for SDL2, and the same three package classes for Mesa.  It is not itself
a distributable package and contains no target binaries.

Each product is split into independent **Libraries**, **Headers** and
**Demos** packages; the binding file list and install order are in
[SPLIT_PACKAGE_CONTRACT.md](SPLIT_PACKAGE_CONTRACT.md).

| File | Purpose | Future repository |
| --- | --- | --- |
| `SDL2_PAYLOAD_MANIFEST.md` | SDL Libraries, Headers and Demos payload contract | `openstep-sdl2` |
| `MESA342_PAYLOAD_MANIFEST.md` | Mesa Libraries, Headers and Demos payload contract | `opennstep-mesa342` |
| `SPLIT_PACKAGE_CONTRACT.md` | shared package names, separation and installation order | both |
| `LICENSE_INVENTORY.md` | Required notices before an asset may be released | both |
| `UPSTREAM_PROVENANCE.md` | Verified source identity and snapshot policy | both |

The final package generator must run the target's
`/NextAdmin/Installer.app/package` command.  It must construct its payload
only from a clean target build and these manifests; it must never package the
working source tree, temporary logs, host tools, credentials, or a previously
installed prefix.

The source repositories contain the metadata, build scripts, verification
scripts, hooks and demo sources.  Generated target `.pkg` directories remain
release artifacts.  GitHub Release assets wait for the documented runtime and
Installer deletion gates.
