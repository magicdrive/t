#!/usr/bin/env bash
# Tests for scripts/lib/release-rules.sh and scripts/check-version.sh, with
# fixed inputs (no network, no git). Run from anywhere. The GitHub-side rules
# (environment, rulesets, tag order) are hephaestus publish check's, tested
# in Hephaestus.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/release-rules.sh
. "$here/lib/release-rules.sh"

fails=0
expect() { # expect yes|no DESCRIPTION COMMAND...
  local want="$1" desc="$2"; shift 2
  if "$@" >/dev/null 2>&1; then got=yes; else got=no; fi
  if [[ "$got" == "$want" ]]; then echo "ok   $desc"; else echo "FAIL $desc (got $got, want $want)"; fails=$((fails + 1)); fi
}

echo "# release tags"
for t in v1.2.0 v1.2.0-rc.1 v1.2.0-rc.10 v0.0.1 v10.20.30 v1.2.0-beta v1.2.0-0 v1.2.0-x-y.1; do
  expect yes "tag $t" release_tag_ok "$t"
done
for t in 1.2.0 v1.2 v1.2.0.1 v01.2.0 v1.02.0 v1.2.0-rc.01 v1.2.0-00 v1.2.0+build v1.2.0-rc..1 v1.2.0- v1.2.0-rc_1 "v1.2.0 " ""; do
  expect no "tag '$t'" release_tag_ok "$t"
done
expect yes "prerelease v1.2.0-rc.1" is_prerelease v1.2.0-rc.1
expect no "prerelease v1.2.0" is_prerelease v1.2.0
equals() { [[ "$1" == "$2" ]]; }
expect yes "release_base v1.2.0-rc.1" equals "$(release_base v1.2.0-rc.1)" v1.2.0
expect yes "release_base v1.2.0" equals "$(release_base v1.2.0)" v1.2.0

echo "# man page"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
man() { printf '.\\" t(1)\n%s\n.SH NAME\nt\n' "$1" > "$tmp/t.1"; }
man '.TH t 1 "2026-10-24" "v1.2.0" "User Commands"'
expect yes "v1.2.0 with t.1 v1.2.0" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
expect yes "v1.2.0-rc.1 with t.1 v1.2.0" "$here/check-version.sh" v1.2.0-rc.1 "$tmp/t.1"
expect no "v1.2.1 with t.1 v1.2.0" "$here/check-version.sh" v1.2.1 "$tmp/t.1"
expect no "v1.3.0-rc.1 with t.1 v1.2.0" "$here/check-version.sh" v1.3.0-rc.1 "$tmp/t.1"
expect no "bad tag with a good t.1" "$here/check-version.sh" v1.2.0+1 "$tmp/t.1"
man '.TH t 1 "2026-10-24" "v1.2.0-rc.1" "User Commands"'
expect no "t.1 with a pre-release version" "$here/check-version.sh" v1.2.0-rc.1 "$tmp/t.1"
man '.TH t 1 "2026-10-24" "1.2.0" "User Commands"'
expect no "t.1 version without v" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
man '.TH t 1 "Oct 2026" "v1.2.0" "User Commands"'
expect no "t.1 with a malformed date" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
man '.TH tmux 1 "2026-10-24" "v1.2.0" "User Commands"'
expect no "t.1 naming another command" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
printf '.TH t 1 "2026-10-24" "v1.2.0"\n.TH t 1 "2026-10-24" "v1.3.0"\n' > "$tmp/t.1"
expect no "two .TH lines" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
printf '.SH NAME\n' > "$tmp/t.1"
expect no "no .TH line" "$here/check-version.sh" v1.2.0 "$tmp/t.1"
expect yes "the repository's t.1 is well-formed" man_version "$here/../t.1"

echo
if (( fails )); then echo "$fails failed"; exit 1; fi
echo "all release rule tests passed"
