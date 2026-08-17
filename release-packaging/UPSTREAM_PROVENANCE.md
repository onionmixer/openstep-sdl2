# Upstream provenance record

Validated: 2026-08-17

| Component | Canonical upstream identity | Local verification | Repository policy |
| --- | --- | --- | --- |
| SDL | `libsdl-org/SDL` tag `release-2.32.10`, commit `5d249570393f7a37e037abf22cd6012a4cc56a71` | A fresh official shallow clone compared recursively with `upstream/SDL-2.32.10`; the clone's `.git` directory was the only extra path | Include the complete pristine `upstream/SDL-2.32.10` snapshot in `openstep-sdl2` |
| Mesa | official `MesaLib-3.4.2.tar.gz`, SHA-256 `b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6` | The tarball checksum matched; a fresh extraction compared recursively with `upstream/Mesa-3.4.2` with no differences | Include the complete pristine `upstream/Mesa-3.4.2` snapshot in `opennstep-mesa342`; retain the source tar hash in release metadata |

No file in either verified source snapshot exceeds 4 MB.  Keeping the
snapshots in the port repositories is therefore feasible and ensures that a
fresh clone can build on an isolated OPENSTEP target without a network fetch.

The port must keep all target-specific changes outside these `upstream/`
directories.  Before every release tag, rerun the applicable comparison above
or verify an equivalent generated file manifest; any difference changes the
record and requires an explicit port patch/notice.
