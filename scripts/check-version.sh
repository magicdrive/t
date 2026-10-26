#!/usr/bin/env bash
# Checks a release tag against the man page before anything is built.
#
# The tag is vMAJOR.MINOR.PATCH[-PRERELEASE] (SemVer 2.0.0, no build
# metadata). The man page carries the release version without the
# pre-release part: t.1 says v1.2.0 for v1.2.0-rc.1, v1.2.0-rc.2 and v1.2.0,
# so a release candidate's commit can be released as the stable version
# unchanged, and a stable tag never ships a man page naming another version.
# Usage: scripts/check-version.sh vX.Y.Z[-PRERELEASE] [man page, default t.1]
#        scripts/check-version.sh --from-make
#
# --from-make reads the version the publish targets of the Makefile export
# (HEPHAESTUS_PUBLISH_ARGS, _VERSION or _TAG; exactly one must be set), so
# the version never passes through a shell command line.
#
# Exit status: 0 the man page names the tag's version, 1 it does not (or it
# is malformed), 2 usage (no version, more than one, or not a release tag).
set -euo pipefail
# shellcheck source=scripts/lib/release-rules.sh
. "$(dirname "$0")/lib/release-rules.sh"

if [[ "${1:-}" == --from-make ]]; then
  [[ $# -eq 1 ]] || { echo "usage: check-version.sh --from-make" >&2; exit 2; }
  tag="" given=0
  for name in HEPHAESTUS_PUBLISH_ARGS HEPHAESTUS_PUBLISH_VERSION HEPHAESTUS_PUBLISH_TAG; do
    if [[ -n "${!name:-}" ]]; then
      tag="${!name}"
      given=$((given + 1))
    fi
  done
  if [[ "$given" -ne 1 ]]; then
    echo "give exactly one version: make publish vX.Y.Z (or VERSION=vX.Y.Z, or tag=vX.Y.Z)" >&2
    exit 2
  fi
  man="$(dirname "$0")/../t.1"
else
  [[ $# -ge 1 && $# -le 2 ]] || { echo "usage: check-version.sh vX.Y.Z[-PRERELEASE] [t.1]" >&2; exit 2; }
  tag="$1"
  man="${2:-t.1}"
fi
release_tag_ok "$tag" || { echo "tag $tag is not vMAJOR.MINOR.PATCH[-PRERELEASE] (SemVer, no build metadata, no leading zeros)"; exit 2; }
version="$(man_version "$man")" || { echo "$man: want exactly one line .TH t 1 \"YYYY-MM-DD\" \"vX.Y.Z\" ..."; exit 1; }
base="$(release_base "$tag")"
[[ "$version" == "$base" ]] || { echo "$man says $version; set its .TH version to $base before tagging $tag"; exit 1; }
kind=stable; is_prerelease "$tag" && kind=prerelease
echo "version OK: $tag ($kind; $(basename "$man") $version)"
