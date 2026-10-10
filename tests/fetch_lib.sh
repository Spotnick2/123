#!/usr/bin/env bash
# fetch_lib.sh - Clone an embedded library at the ref .pkgmeta pins, and
# prove the checkout IS that ref. CI runs it before the tests (they load the
# libraries from $LIBGLASS and $LIBSHOWCASE); it also works locally from git bash.
#
# The url and the pin are read from .pkgmeta, the one place they are written,
# so CI tests exactly what the packager will embed.
#
# Usage (from the repo root):  bash tests/fetch_lib.sh <Lib-1.0> <dest>
#   e.g. bash tests/fetch_lib.sh LibGlass-1.0 "$RUNNER_TEMP/LibGlass"
#
# <dest> must not exist: the script never deletes anything (a default of
# ../LibGlass would have wiped the dev checkout, uncommitted work included).
set -euo pipefail

name="${1:-}"
dest="${2:-}"
if [ -z "$name" ] || [ -z "$dest" ]; then
    echo "usage: bash tests/fetch_lib.sh <Lib-1.0> <dest>   (a path that does not exist yet)" >&2
    exit 2
fi
if [ -e "$dest" ]; then
    echo "$dest already exists; refusing to touch it (pick a fresh path)" >&2
    exit 1
fi

# The Libs/<name> entry of the externals block.
entry=$(tr -d '\r' < .pkgmeta | awk -v key="  Libs/$name:" '
    /^externals:/ { inext = 1; next }
    inext && /^[^ #]/ { inext = 0 }
    inext && $0 == key { inlib = 1; next }
    inlib && /^  [^ ]/ { inlib = 0 }
    inext && inlib')
# Values are read the way the packager reads them: the whole rest of the line.
# Its YAML reader keeps an inline "# comment" as part of the value, so a
# comment there must fail here too, not only in the packaging step.
url=$(printf '%s\n' "$entry" | sed -n 's/^ *url: *\(.*[^ ]\) *$/\1/p')
kind=$(printf '%s\n' "$entry" | sed -n 's/^ *\(commit\|tag\): *\(.*[^ ]\) *$/\1/p')
ref=$(printf '%s\n' "$entry" | sed -n 's/^ *\(commit\|tag\): *\(.*[^ ]\) *$/\2/p')
if [ -z "$url" ] || [ -z "$ref" ]; then
    echo "no url and commit/tag pin for Libs/$name in .pkgmeta" >&2
    exit 1
fi

echo "$name: $kind $ref from $url -> $dest"
# A full clone: a commit pin can't be fetched with --branch (the packager does
# the same for `commit:`).
git clone -q "$url" "$dest"
git -C "$dest" -c advice.detachedHead=false checkout -q "$ref"

# The pinned-commit check: HEAD must be the commit the pin names.
want=$(git -C "$dest" rev-parse --verify "$ref^{commit}")
head=$(git -C "$dest" rev-parse HEAD)
if [ "$head" != "$want" ]; then
    echo "$name checkout is at $head, but .pkgmeta pins $kind $ref ($want)" >&2
    exit 1
fi
echo "$name checkout at $head (pinned $kind $ref)"
