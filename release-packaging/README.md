# Release packaging workspace

This directory is the P0 source of truth for splitting the completed work
into two independent OPENSTEP Developer-style Installer packages.  It is not
itself a distributable package and contains no target binaries.

The delivery is split further into independent **Libraries** and **Headers**
packages for each product; the binding file list and install order are in
[SPLIT_PACKAGE_CONTRACT.md](SPLIT_PACKAGE_CONTRACT.md).

| File | Purpose | Future repository |
| --- | --- | --- |
| `SDL2_PAYLOAD_MANIFEST.md` | SDL headers, archive, documentation and exclusions | `openstep-sdl2` |
| `MESA342_PAYLOAD_MANIFEST.md` | Mesa headers, archives, documentation and exclusions | `opennstep-mesa342` |
| `OpenStepSDL2.info` | Installer metadata template | `openstep-sdl2` |
| `OpenStepMesa342.info` | Installer metadata template | `opennstep-mesa342` |
| `LICENSE_INVENTORY.md` | Required notices before an asset may be released | both |
| `UPSTREAM_PROVENANCE.md` | Verified source identity and snapshot policy | both |

The final package generator must run the target's
`/NextAdmin/Installer.app/package` command.  It must construct its payload
only from a clean target build and these manifests; it must never package the
working source tree, temporary logs, host tools, credentials, or a previously
installed prefix.

The source repositories and GitHub releases remain intentionally absent until
the payload manifests, clean rebuilds and actual Installer install/delete
tests have passed.
