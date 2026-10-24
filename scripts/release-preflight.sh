#!/usr/bin/env bash
# Read-only checks before pushing a release tag. Nothing is created, pushed
# or changed on GitHub; the only local change is a fetch of origin/master.
#
#   scripts/release-preflight.sh v1.2.0-rc.1      (make release-preflight TAG=...)
#
# Needs git, gh (authenticated) and jq. Every check prints ok or FAIL; the
# exit status is non-zero when any check fails. Pushing the tag afterwards is
# the only release trigger (docs/releasing.md).

# `test && ok ... || bad ...` is safe here: ok and bad always succeed.
# shellcheck disable=SC2015
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=scripts/lib/release-rules.sh
. scripts/lib/release-rules.sh

tag="${1:?usage: release-preflight.sh vX.Y.Z[-PRERELEASE]}"
repo=magicdrive/t
branch=master
env_name=release
tap=magicdrive/homebrew-tap
formula=t.rb
secret=HOMEBREW_TAP_GITHUB_TOKEN
required_check=ci-gate

failed=0
ok()   { printf '  [ok  ] %-22s %s\n' "$1" "$2"; }
bad()  { printf '  [FAIL] %-22s %s\n' "$1" "$2"; failed=1; }
info() { printf '  [info] %-22s %s\n' "$1" "$2"; }
check() { # check NAME COMMAND...: ok/FAIL with the command's last line
  local name="$1" out; shift
  if out="$("$@" 2>&1)"; then ok "$name" "${out##*$'\n'}"; else bad "$name" "${out##*$'\n'}"; fi
}

echo "Release preflight for $tag ($repo)"

# Version
if ! release_tag_ok "$tag"; then
  bad "tag format" "$tag is not vMAJOR.MINOR.PATCH[-PRERELEASE]"
  exit 1
fi
version="${tag#v}"
kind=stable; is_prerelease "$tag" && kind=prerelease
ok "tag format" "$tag ($kind)"
check "man page version" scripts/check-version.sh "$tag"

# Git
current="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "$current" == "$branch" ]] && ok "branch" "$branch" || bad "branch" "on '${current:-detached HEAD}', releases are tagged on $branch"
dirty="$(git status --porcelain --untracked-files=all)"
[[ -z "$dirty" ]] && ok "worktree" "clean" || bad "worktree" "$(wc -l <<<"$dirty" | tr -d ' ') uncommitted or untracked paths"
if git fetch --quiet --no-tags origin "+refs/heads/$branch:refs/remotes/origin/$branch"; then
  head="$(git rev-parse HEAD)"; remote="$(git rev-parse "origin/$branch")"
  [[ "$head" == "$remote" ]] && ok "in sync with origin" "HEAD = origin/$branch = $head" \
    || bad "in sync with origin" "HEAD ${head:0:12} != origin/$branch ${remote:0:12}"
else
  bad "in sync with origin" "git fetch failed"; head=""
fi
git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null && bad "local tag" "$tag exists locally" || ok "local tag" "$tag does not exist"
remote_tags="$(git ls-remote --tags --refs origin)" || { bad "remote tag" "git ls-remote failed"; remote_tags=""; }
grep -q "refs/tags/$tag\$" <<<"$remote_tags" && bad "remote tag" "$tag exists on origin" || ok "remote tag" "$tag does not exist on origin"
tag_names=()
while read -r _ ref; do [[ -n "${ref:-}" ]] && tag_names+=("${ref#refs/tags/}"); done <<<"$remote_tags"
latest="$(highest_stable "${tag_names[@]}")"
if [[ -z "$latest" ]] || version_gt "$(release_base "$tag")" "$latest"; then
  ok "newer than releases" "$(release_base "$tag") > ${latest:-(none)}"
else
  bad "newer than releases" "$(release_base "$tag") is not newer than the released $latest"
fi

# GitHub
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  bad "gh auth" "gh is not authenticated"; echo; echo "preflight FAILED"; exit 1
fi
# api prints the response, or nothing (and fails) on an error: gh would
# print the error body on stdout.
api() { local out; out="$(gh api -H "Accept: application/vnd.github+json" "$@")" || return 1; printf '%s\n' "$out"; }
if [[ -n "${head:-}" ]]; then
  run="$(api "repos/$repo/actions/workflows/ci.yml/runs?event=push&branch=$branch&head_sha=$head&per_page=20" \
    --jq '[.workflow_runs[] | select(.head_sha == "'"$head"'" and .event == "push")] | sort_by(.created_at) | last | [.status, .conclusion, .html_url] | @tsv')"
  IFS=$'\t' read -r st co url <<<"$run"
  if [[ "$st" == completed && "$co" == success ]]; then ok "ci on commit" "ci.yml succeeded on ${head:0:12} ($url)"
  elif [[ -z "$st" ]]; then bad "ci on commit" "no ci.yml push run on $branch for ${head:0:12}"
  else bad "ci on commit" "ci.yml is $st/${co:-} ($url)"; fi
fi
wf="$(api "repos/$repo/actions/workflows/release.yml" --jq .state)"
[[ "$wf" == active ]] && ok "release workflow" "release.yml active" || bad "release workflow" "release.yml state '${wf:-missing}'"

envjson="$(api "repos/$repo/environments/$env_name")"
if [[ -z "$envjson" ]]; then
  bad "environment" "environment $env_name does not exist"
else
  pol="$(api "repos/$repo/environments/$env_name/deployment-branch-policies?per_page=100" --jq '.branch_policies' || echo '[]')"
  combined="$(jq -n --argjson e "$envjson" --argjson p "$pol" '{custom_branch_policies: ($e.deployment_branch_policy.custom_branch_policies // false), protected_branches: ($e.deployment_branch_policy.protected_branches // false), policies: $p}')"
  check "environment" env_allows_only_tag "$tag" <<<"$combined"
fi

ids="$(api "repos/$repo/rulesets?includes_parents=true&per_page=100" --jq '.[].id')"
sets="$(for id in $ids; do api "repos/$repo/rulesets/$id" || echo '{}'; done | jq -s '.')"
check "tag ruleset" tag_ruleset_protects "$tag" <<<"$sets"
check "$branch ruleset" branch_ruleset_requires "$branch" "$required_check" <<<"$sets"

rel="$(api "repos/$repo/releases?per_page=100" --jq '.[] | select(.tag_name == "'"$tag"'") | if .draft then "draft" else "published" end')"
[[ -z "$rel" ]] && ok "no release yet" "no release or draft for $tag" || bad "no release yet" "a $rel release for $tag exists"

# Homebrew tap
if is_prerelease "$tag"; then
  info "homebrew tap" "skipped for prereleases (skip_upload: auto); the tap token is not used"
else
  names="$(api "repos/$repo/environments/$env_name/secrets" --jq '.secrets[].name')"
  grep -qx "$secret" <<<"$names" && ok "tap token secret" "$secret in $env_name (name only)" || bad "tap token secret" "$secret missing in $env_name"
  contents="$(api "repos/$tap/contents/")"
  if [[ -z "$contents" ]]; then
    bad "tap repository" "$tap is not readable"
  else
    ok "tap repository" "$tap"
    jq -e 'any(.[]; .type == "dir" and (.name == "Formula" or .name == "HomebrewFormula"))' <<<"$contents" >/dev/null \
      && bad "tap layout" "$tap has Formula/ or HomebrewFormula/: a root $formula would be hidden" \
      || ok "tap layout" "formulae at the root; $formula goes there"
    prs="$(api "repos/$tap/pulls?state=all&head=magicdrive:t-$version&per_page=5" --jq 'length')"
    [[ "${prs:-0}" == 0 ]] && ok "tap pull request" "will open from magicdrive:t-$version" || bad "tap pull request" "a pull request from t-$version already exists"
    api "repos/$tap/git/ref/heads/t-$version" >/dev/null 2>&1 && bad "tap branch" "branch t-$version already exists" || ok "tap branch" "t-$version does not exist yet"
  fi
fi

echo
if (( failed )); then echo "preflight FAILED for $tag: do not push the tag"; exit 1; fi
echo "preflight passed: git tag -a $tag -m $tag && git push origin refs/tags/$tag"
