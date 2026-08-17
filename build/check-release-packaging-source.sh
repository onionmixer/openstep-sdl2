#!/bin/sh
# Validate the source-side contract before any OPENSTEP Installer package is
# generated.  This deliberately does not build, stage, install or publish.

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
packaging="$root/release-packaging"

require_file() {
    if [ ! -f "$1" ]; then
        echo "check-release-packaging-source: missing $1" >&2
        exit 1
    fi
}

require_field() {
    file=$1
    field=$2
    if ! awk -v field="$field" '
        $1 == field && length($0) > length(field) { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$file"; then
        echo "check-release-packaging-source: $file lacks $field" >&2
        exit 1
    fi
}

for file in \
    "$root/RELEASE_PACKAGING_PLAN.md" \
    "$packaging/README.md" \
    "$packaging/SDL2_PAYLOAD_MANIFEST.md" \
    "$packaging/MESA342_PAYLOAD_MANIFEST.md" \
    "$packaging/OpenStepSDL2.info" \
    "$packaging/OpenStepMesa342.info" \
    "$packaging/LICENSE_INVENTORY.md" \
    "$packaging/UPSTREAM_PROVENANCE.md" \
    "$packaging/SPLIT_PACKAGE_CONTRACT.md" \
    "$root/upstream/SDL-2.32.10/LICENSE.txt" \
    "$root/upstream/Mesa-3.4.2/docs/COPYRIGHT" \
    "$root/upstream/Mesa-3.4.2/docs/COPYING" \
    "$root/port/openstep/include/SDL_config_openstep.h" \
    "$root/port/openstep/include/stdint.h" \
    "$root/port/openstep/src/cpuinfo/SDL_openstepcpuinfo.c" \
    "$root/test/openstep/check-sdl2-archive-cpu.csh" \
    "$root/packaging/openstep/build-package.csh" \
    "$root/packaging/openstep/verify-package.csh" \
    "$root/packaging/openstep/OpenStepSDL2.pre_install" \
    "$root/packaging/openstep/OpenStepSDL2.post_install" \
    "$root/packaging/openstep/OpenStepSDL2Headers.pre_install" \
    "$root/packaging/openstep/installer-architecture-marker.c" \
    "$root/packaging/openstep/build-split-packages.csh" \
    "$root/packaging/openstep/OpenStepSDL2Libraries.info" \
    "$root/packaging/openstep/OpenStepSDL2Headers.info" \
    "$root/release-docs/README.OPENSTEP" \
    "$root/release-docs/API-COVERAGE.md" \
    "$root/release-docs/PORT-NOTES.md" \
    "$root/release-docs/LINKING.md" \
    "$root/release-docs/RELEASE-MANIFEST.txt" \
    "$root/release-examples/sdl2/sdl2_clear.c" \
    "$root/release-examples/sdl2/build-sdl2-clear.csh"
do
    require_file "$file"
done

for info in "$packaging/OpenStepSDL2.info" "$packaging/OpenStepMesa342.info"
do
    for field in Title Version Description DefaultLocation Relocatable Application UseUserMask DiskName DeleteWarning
    do
        require_field "$info" "$field"
    done
    if ! grep -qx 'DefaultLocation /LocalDeveloper' "$info" || \
       ! grep -qx 'Relocatable YES' "$info" || \
       ! grep -qx 'Application NO' "$info" || \
       ! grep -qx 'UseUserMask NO' "$info"; then
        echo "check-release-packaging-source: unsafe Installer policy in $info" >&2
        exit 1
    fi
done

for header in gl.h glext.h glu.h glu_mangle.h osmesa.h
do
    require_file "$root/upstream/Mesa-3.4.2/include/GL/$header"
done

if ! grep -q 'SDL_config_openstep.h' "$packaging/SDL2_PAYLOAD_MANIFEST.md" || \
   ! grep -q 'check-final-api-manifest.csh' "$packaging/SDL2_PAYLOAD_MANIFEST.md" || \
   ! grep -q 'libGL.a' "$packaging/MESA342_PAYLOAD_MANIFEST.md" || \
   ! grep -q 'osmesa.o' "$packaging/MESA342_PAYLOAD_MANIFEST.md"; then
    echo "check-release-packaging-source: payload invariants missing" >&2
    exit 1
fi

if ! grep -q '5d249570393f7a37e037abf22cd6012a4cc56a71' "$packaging/UPSTREAM_PROVENANCE.md" || \
   ! grep -q 'b02b5f77321175820b9955b07979d9f8c5d52e146eecc719844380ef2849ddd6' "$packaging/UPSTREAM_PROVENANCE.md"; then
    echo "check-release-packaging-source: upstream provenance is incomplete" >&2
    exit 1
fi

if grep -RinE '(^|[^[:alnum:]_])(GCD|GrandCross|site\.conf|gcds)([^[:alnum:]_]|$)' "$packaging"; then
    echo "check-release-packaging-source: site-specific remote material is forbidden" >&2
    exit 1
fi

if ! grep -q 'OPENSTEP/i386 CPU-information backend' "$root/port/openstep/src/cpuinfo/SDL_openstepcpuinfo.c" || \
   ! grep -q 'all members i386' "$root/test/openstep/check-sdl2-archive-cpu.csh"; then
    echo "check-release-packaging-source: i386 CPU archive contract is incomplete" >&2
    exit 1
fi

echo "check-release-packaging-source: PASS Installer metadata, payload closure and license inputs"
