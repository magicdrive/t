# shellcheck shell=bash
# Release rules shared by check-version.sh, release-preflight.sh and their
# tests. Pure functions: no network, no git; GitHub API responses are passed
# in as JSON.

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

# version_gt A B: A > B for vMAJOR.MINOR.PATCH.
version_gt() {
  local a="${1#v}" b="${2#v}" i
  local -a x y
  IFS=. read -r -a x <<<"$a"
  IFS=. read -r -a y <<<"$b"
  for i in 0 1 2; do
    (( x[i] > y[i] )) && return 0
    (( x[i] < y[i] )) && return 1
  done
  return 1
}

# highest_stable TAGS...: the highest vX.Y.Z among the arguments (prereleases
# and other names ignored), or nothing.
highest_stable() {
  local best="" t
  for t in "$@"; do
    [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    if [[ -z "$best" ]] || version_gt "$t" "$best"; then best="$t"; fi
  done
  [[ -n "$best" ]] && printf '%s\n' "$best"
  return 0
}

# env_allows_only_tag TAG < environment-and-policies JSON
#   {"custom_branch_policies": bool, "protected_branches": bool,
#    "policies": [{"name","type"}]}
# Deployments must come from tag policies only, one of which matches TAG.
env_allows_only_tag() {
  local tag="$1" json name type matched=1
  json="$(cat)"
  [[ "$(jq -r '.custom_branch_policies' <<<"$json")" == true ]] || { echo "no custom deployment policy: any branch or tag can deploy"; return 1; }
  while IFS=$'\t' read -r name type; do
    [[ -z "$name" ]] && continue
    [[ "$type" == tag ]] || { echo "also deploys from $type \"$name\"; want tags only"; return 1; }
    # shellcheck disable=SC2053 # $name is a glob pattern on purpose
    [[ "$tag" == $name ]] && matched=0
  done < <(jq -r '.policies[] | [.name, .type] | @tsv' <<<"$json")
  (( matched == 0 )) || { echo "no tag policy matches $tag"; return 1; }
  echo "deploys only from tags matching $tag"
}

# ref_matches PATTERN REF DEFAULT_BRANCH: ruleset ref_name pattern semantics
# (fnmatch; ~ALL; ~DEFAULT_BRANCH).
ref_matches() {
  case "$1" in
    "~ALL") return 0 ;;
    "~DEFAULT_BRANCH") [[ "$2" == "refs/heads/$3" ]]; return ;;
  esac
  # shellcheck disable=SC2053
  [[ "$2" == $1 ]]
}

# ruleset_covers REF DEFAULT_BRANCH < ruleset JSON
ruleset_covers() {
  local ref="$1" def="$2" json p inc=1
  json="$(cat)"
  while IFS= read -r p; do [[ -n "$p" ]] && ref_matches "$p" "$ref" "$def" && inc=0; done < <(jq -r '.conditions.ref_name.include[]?' <<<"$json")
  (( inc == 0 )) || return 1
  while IFS= read -r p; do [[ -n "$p" ]] && ref_matches "$p" "$ref" "$def" && return 1; done < <(jq -r '.conditions.ref_name.exclude[]?' <<<"$json")
  return 0
}

# tag_ruleset_protects TAG < JSON array of full rulesets
# An active tag ruleset covering TAG forbids deletion and update; no active
# ruleset covering TAG blocks creating it.
tag_ruleset_protects() {
  local tag="$1" all i n rs types ok=""
  all="$(cat)"
  n="$(jq 'length' <<<"$all")"
  for ((i = 0; i < n; i++)); do
    rs="$(jq ".[$i]" <<<"$all")"
    [[ "$(jq -r '.target' <<<"$rs")" == tag && "$(jq -r '.enforcement' <<<"$rs")" == active ]] || continue
    ruleset_covers "refs/tags/$tag" "" <<<"$rs" || continue
    types=" $(jq -r '[.rules[].type] | join(" ")' <<<"$rs") "
    [[ "$types" == *" creation "* ]] && { echo "ruleset \"$(jq -r .name <<<"$rs")\" blocks creating $tag"; return 1; }
    [[ "$types" == *" deletion "* && "$types" == *" update "* ]] && ok="$(jq -r .name <<<"$rs")"
  done
  [[ -n "$ok" ]] || { echo "no active tag ruleset forbids deleting and updating refs/tags/$tag"; return 1; }
  echo "\"$ok\": deletion and update forbidden, creation allowed"
}

# branch_ruleset_requires BRANCH CHECK < JSON array of full rulesets
branch_ruleset_requires() {
  local branch="$1" check="$2" all i n rs
  all="$(cat)"
  n="$(jq 'length' <<<"$all")"
  for ((i = 0; i < n; i++)); do
    rs="$(jq ".[$i]" <<<"$all")"
    [[ "$(jq -r '.target' <<<"$rs")" == branch && "$(jq -r '.enforcement' <<<"$rs")" == active ]] || continue
    ruleset_covers "refs/heads/$branch" "$branch" <<<"$rs" || continue
    if jq -e --arg c "$check" 'any(.rules[]; .type == "required_status_checks" and any(.parameters.required_status_checks[]?; .context == $c))' <<<"$rs" >/dev/null; then
      echo "\"$(jq -r .name <<<"$rs")\" requires $check on $branch"
      return 0
    fi
  done
  echo "no active ruleset requires $check on $branch"
  return 1
}
