#!/bin/sh
# Generate the OPENSTEP-preprocessed SDL2 dynapi symbol baseline on the host.
# The result is source analysis only; final archive nm(1) comparison is run on
# the real OPENSTEP target.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
output=${1:-"$project_root/notes/SDL2.32.10.OPENSTEP_API_MANIFEST.txt"}
temporary=$(mktemp "${TMPDIR:-/tmp}/sdl20-api-manifest.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM

# Do not let the host's Linux platform selector leak into the SDL dynapi
# conditional records. Modern host cpp is used only because the target's
# GCC 2.7 cpp cannot parse their variadic macro arguments.
cc -E -D__OPENSTEP__ -U__linux__ -Ulinux "$script_dir/api-manifest-host.c" > "$temporary"
sed -n 's/^SDL_OPENSTEP_API_//p' "$temporary" | LC_ALL=C sort -u > "$output"
wc -l "$output"
