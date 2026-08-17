#!/bin/sh
# Check that the OpenStep-visible SDL2 runtime declarations in the upstream
# public headers are exactly the declarations represented by the final ABI
# manifest.  This is a host preprocessor audit; target nm(1) verification is
# intentionally retained in check-final-api-manifest.csh.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/.." && pwd)
upstream="$root/upstream/SDL-2.32.10"
config="$root/port/openstep/include/SDL_config_openstep.h"
checked_manifest="$root/notes/SDL2.32.10.OPENSTEP_API_MANIFEST.txt"
temporary=$(mktemp -d "${TMPDIR:-/tmp}/sdl20-public-header-audit.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

if [ ! -r "$upstream/include/SDL.h" ] || [ ! -r "$config" ] || [ ! -r "$checked_manifest" ]; then
    echo "check-openstep-public-header-coverage: missing SDL source, OpenStep config, or manifest" >&2
    exit 2
fi

# SDL_platform.h maps host compiler predefines to SDL platform markers.  The
# host is used only to parse modern declarations, so remove all Linux markers
# before including the OpenStep configuration.  In particular, -U__linux is
# necessary on GCC hosts; -U__linux__ alone is insufficient.
cc -E -P \
    -D__OPENSTEP__ -U__linux__ -U__linux -Ulinux -U__gnu_linux__ \
    -I"$upstream/include" -include "$config" \
    "$script_dir/public-header-audit.c" > "$temporary/headers.i"

# Collect the final SDL_* function identifier from each public extern
# declaration.  Declarations can span lines, so do not use a line-oriented
# grep.  The preprocessed output makes one semicolon a complete declaration.
awk '
function emit(line, name, token) {
    name = ""
    while (match(line, /SDL_[A-Za-z0-9_]*[ \t]*\(/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/[ \t]*\($/, "", token)
        name = token
        line = substr(line, RSTART + RLENGTH)
    }
    if (name != "") print name
}
{
    if (decl != "") {
        decl = decl " " $0
    } else if ($0 ~ /^extern /) {
        decl = $0
    }
    if (decl != "" && $0 ~ /;/) {
        emit(decl)
        decl = ""
    }
}
' "$temporary/headers.i" | LC_ALL=C sort -u > "$temporary/header-symbols-all.txt"

# SDL_main is declared by SDL_main.h but is an application entry point.  It
# must be supplied by the application, never by libSDL2.a.
grep -v '^SDL_main$' "$temporary/header-symbols-all.txt" > "$temporary/header-symbols.txt"

sh "$script_dir/generate-api-manifest-host.sh" "$temporary/dynapi-symbols.txt" >/dev/null
if ! cmp -s "$temporary/dynapi-symbols.txt" "$checked_manifest"; then
    echo "check-openstep-public-header-coverage: checked-in dynapi manifest is stale" >&2
    exit 1
fi

comm -23 "$temporary/header-symbols.txt" "$temporary/dynapi-symbols.txt" > "$temporary/header-only.txt"
comm -13 "$temporary/header-symbols.txt" "$temporary/dynapi-symbols.txt" > "$temporary/dynapi-only.txt"

if [ -s "$temporary/header-only.txt" ] || [ -s "$temporary/dynapi-only.txt" ]; then
    echo "check-openstep-public-header-coverage: FAIL declaration/manifest mismatch" >&2
    if [ -s "$temporary/header-only.txt" ]; then
        echo "header declarations absent from dynapi manifest:" >&2
        cat "$temporary/header-only.txt" >&2
    fi
    if [ -s "$temporary/dynapi-only.txt" ]; then
        echo "dynapi entries absent from runtime public headers:" >&2
        cat "$temporary/dynapi-only.txt" >&2
    fi
    exit 1
fi

header_count=$(wc -l < "$temporary/header-symbols.txt")
manifest_count=$(wc -l < "$temporary/dynapi-symbols.txt")
if [ "$header_count" -ne 836 ] || [ "$manifest_count" -ne 836 ]; then
    echo "check-openstep-public-header-coverage: unexpected SDL 2.32.10 OpenStep baseline $header_count/$manifest_count" >&2
    exit 1
fi

echo "check-openstep-public-header-coverage: PASS $header_count runtime declarations; SDL_main is application-owned"
