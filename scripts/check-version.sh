#!/usr/bin/env bash
# Checks a release tag against the man page before anything is built.
#
# The tag is vMAJOR.MINOR.PATCH[-PRERELEASE] (SemVer 2.0.0, no build
# metadata). The man page carries the release version without the
# pre-release part: t.1 says v1.2.0 for v1.2.0-rc.1, v1.2.0-rc.2 and v1.2.0,
# so a release candidate's commit can be released as the stable version
# unchanged, and a stable tag never ships a man page naming another version.
# Usage: scripts/check-version.sh vX.Y.Z[-PRERELEASE] [man page, default t.1]
set -euo pipefail
# shellcheck source=scripts/lib/release-rules.sh
. "$(dirname "$0")/lib/release-rules.sh"

tag="${1:?usage: check-version.sh vX.Y.Z[-PRERELEASE] [t.1]}"
man="${2:-t.1}"
release_tag_ok "$tag" || { echo "tag $tag is not vMAJOR.MINOR.PATCH[-PRERELEASE] (SemVer, no build metadata, no leading zeros)"; exit 1; }
version="$(man_version "$man")" || { echo "$man: want exactly one line .TH t 1 \"YYYY-MM-DD\" \"vX.Y.Z\" ..."; exit 1; }
base="$(release_base "$tag")"
[[ "$version" == "$base" ]] || { echo "$man says $version; set its .TH version to $base before tagging $tag"; exit 1; }
kind=stable; is_prerelease "$tag" && kind=prerelease
echo "version OK: $tag ($kind; $man $version)"
