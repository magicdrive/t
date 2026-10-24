#!/usr/bin/env bash
# Checks that a release tag is vMAJOR.MINOR.PATCH[-PRERELEASE] and that the
# man page carries that version (without the pre-release part), so a
# release never ships a man page with another version.
# Usage: scripts/check-version.sh v1.2.0
set -euo pipefail
tag="${1:?usage: check-version.sh vX.Y.Z}"
semver='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
[[ "$tag" =~ $semver ]] || { echo "tag $tag is not vMAJOR.MINOR.PATCH[-PRERELEASE]"; exit 1; }
base="${tag%%-*}"
man="$(awk '$1 == ".TH" { print $5; exit }' t.1 | tr -d '"')"
[[ "$man" == "$base" ]] || { echo "t.1 says version $man; update its .TH line to $base before tagging $tag"; exit 1; }
echo "version OK: $tag (t.1 $man)"
