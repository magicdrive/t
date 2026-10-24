#!/usr/bin/env bash
# Tests for scripts/lib/release-rules.sh and scripts/check-version.sh, with
# fixed inputs (no network, no git). Run from anywhere.
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
with_json() { local json="$1"; shift; "$@" <<<"$json"; }

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

echo "# version order"
expect yes "v1.2.0 > v1.1.1" version_gt v1.2.0 v1.1.1
expect yes "v1.10.0 > v1.9.9" version_gt v1.10.0 v1.9.9
expect no "v1.1.1 > v1.1.1" version_gt v1.1.1 v1.1.1
expect no "v1.1.0 > v1.1.1" version_gt v1.1.0 v1.1.1
expect yes "highest_stable ignores prereleases" equals "$(highest_stable v0.0.1 v1.0.0 v1.1.1 v1.1.0 v1.2.0-rc.1 latest)" v1.1.1
expect yes "highest_stable of nothing" equals "$(highest_stable)" ""

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

echo "# environment"
env_json() { jq -n --argjson c "$1" --argjson p "$2" '{custom_branch_policies: $c, protected_branches: false, policies: $p}'; }
expect yes "tag v* only" with_json "$(env_json true '[{"name":"v*","type":"tag"}]')" env_allows_only_tag v1.2.0-rc.1
expect no "branch v* (current magicdrive/t)" with_json "$(env_json true '[{"name":"v*","type":"branch"}]')" env_allows_only_tag v1.2.0-rc.1
expect no "tag v* plus branch master" with_json "$(env_json true '[{"name":"v*","type":"tag"},{"name":"master","type":"branch"}]')" env_allows_only_tag v1.2.0
expect no "tag policy not matching" with_json "$(env_json true '[{"name":"release-*","type":"tag"}]')" env_allows_only_tag v1.2.0
expect no "no custom policy" with_json "$(env_json false '[]')" env_allows_only_tag v1.2.0

echo "# rulesets"
rs() { # rs NAME TARGET ENFORCEMENT INCLUDE-JSON EXCLUDE-JSON RULES-JSON
  jq -n --arg n "$1" --arg t "$2" --arg e "$3" --argjson i "$4" --argjson x "$5" --argjson r "$6" \
    '{name: $n, target: $t, enforcement: $e, conditions: {ref_name: {include: $i, exclude: $x}}, rules: $r}'
}
tagrules='[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"update"}]'
mainrules='[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request"},{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"ci-gate"}]}}]'
good="$(jq -s . <(rs "Protect master" branch active '["refs/heads/master"]' '[]' "$mainrules") <(rs "Protect release tags" tag active '["refs/tags/v*"]' '[]' "$tagrules"))"
expect yes "tag ruleset active" with_json "$good" tag_ruleset_protects v1.2.0-rc.1
expect yes "master ruleset requires ci-gate" with_json "$good" branch_ruleset_requires master ci-gate
expect no "master ruleset requires another check" with_json "$good" branch_ruleset_requires master other
expect no "no rulesets (current magicdrive/t)" with_json '[]' tag_ruleset_protects v1.2.0
expect no "no rulesets: master" with_json '[]' branch_ruleset_requires master ci-gate
expect no "tag ruleset disabled" with_json "$(jq -s . <(rs t tag disabled '["refs/tags/v*"]' '[]' "$tagrules"))" tag_ruleset_protects v1.2.0
expect no "tag ruleset in evaluate mode" with_json "$(jq -s . <(rs t tag evaluate '["refs/tags/v*"]' '[]' "$tagrules"))" tag_ruleset_protects v1.2.0
expect no "tag ruleset without update" with_json "$(jq -s . <(rs t tag active '["refs/tags/v*"]' '[]' '[{"type":"deletion"}]'))" tag_ruleset_protects v1.2.0
expect no "tag ruleset blocking creation" with_json "$(jq -s . <(rs t tag active '["~ALL"]' '[]' '[{"type":"creation"},{"type":"deletion"},{"type":"update"}]'))" tag_ruleset_protects v1.2.0
expect no "tag excluded" with_json "$(jq -s . <(rs t tag active '["refs/tags/v*"]' '["refs/tags/v1.*"]' "$tagrules"))" tag_ruleset_protects v1.2.0
expect yes "~DEFAULT_BRANCH" with_json "$(jq -s . <(rs m branch active '["~DEFAULT_BRANCH"]' '[]' "$mainrules"))" branch_ruleset_requires master ci-gate

echo
if (( fails )); then echo "$fails failed"; exit 1; fi
echo "all release rule tests passed"
