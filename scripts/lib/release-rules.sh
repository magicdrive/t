# shellcheck shell=bash
# Release rules of check-version.sh, test-publish-make.sh and their tests.
# Pure functions: no network, no git. The checks against GitHub (environment,
# rulesets, tag order, tap) are made by hephaestus publish check (make
# publish-check), not here.

# release_tag_ok TAG: vMAJOR.MINOR.PATCH[-PRERELEASE], SemVer 2.0.0 without
# build metadata; numeric identifiers have no leading zeros.
release_tag_ok() {
  local tag="$1" num='(0|[1-9][0-9]*)' id
  [[ "$tag" =~ ^v${num}\.${num}\.${num}(-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$ ]] || return 1
  local pre="${BASH_REMATCH[5]}"
  [[ -z "$pre" ]] && return 0
  local IFS=.
  for id in $pre; do
    [[ "$id" =~ ^[0-9]+$ && "$id" =~ ^0[0-9] ]] && return 1
  done
  return 0
}

# release_base TAG: the tag without its pre-release part (v1.2.0-rc.1 -> v1.2.0).
release_base() { printf '%s\n' "${1%%-*}"; }

# is_prerelease TAG
is_prerelease() { [[ "$1" == *-* ]]; }

# man_version FILE: the version of the single `.TH t 1 "DATE" "vX.Y.Z" ...`
# line, or a non-zero status when the line is missing, repeated or malformed.
man_version() {
  local th
  th="$(grep -c '^\.TH ' "$1")" || true
  [[ "$th" == 1 ]] || return 1
  awk '$1 == ".TH" {
    if ($2 != "t" || $3 != "1") exit 1
    if ($4 !~ /^"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"$/) exit 1
    v = $5; gsub(/"/, "", v)
    if (v !~ /^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/) exit 1
    print v
  }' "$1"
}
