#!/usr/bin/env bash
# Mutation tests of scripts/check-workflows.rb: it passes on the workflows as
# they are, and fails on each copy below broken in one way that would weaken
# the release (a tap token reaching a prerelease, no plan, two Hephaestus
# versions, a job without a timeout, ...).
# Usage: scripts/test-check-workflows.sh   (make test-release)
# The mutations are Ruby expressions, single-quoted on purpose: ${{ ... }} in
# them is workflow text, not a shell expansion.
# shellcheck disable=SC2016
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
failed=0

# mutate NAME FILE RUBY-EXPR: copies the workflows, rewrites FILE with
# RUBY-EXPR (applied to its text `s`, must change it) and expects the check
# to fail.
mutate() {
  local name="$1" file="$2" expr="$3" dir="$tmp/$RANDOM$RANDOM"
  mkdir -p "$dir/.github" "$dir/scripts"
  cp -R .github/workflows "$dir/.github/"
  cp scripts/check-workflows.rb "$dir/scripts/"
  cp Makefile "$dir/"
  if ! ruby -e 'p = ARGV[0]; s = File.read(p); t = eval(ARGV[1]); abort("does not apply") if t == s; File.write(p, t)' "$dir/$file" "$expr"; then
    echo "FAIL mutation '$name' no longer applies to $file"; failed=1; return
  fi
  if (cd "$dir" && ruby scripts/check-workflows.rb >"$dir/out" 2>&1); then
    echo "FAIL mutation '$name' passes the check"; failed=1
  else
    echo "ok   $name: $(grep -m1 '^FAIL' "$dir/out")"
  fi
}

ruby scripts/check-workflows.rb >/dev/null || { echo "FAIL the check fails on the workflows themselves"; exit 1; }
echo "ok   the workflows pass the check"

rel=.github/workflows/release.yml
ci=.github/workflows/ci.yml
tap_if="        if: steps.plan.outputs.tap == 'publish'"
mutate "rehearsal without the plan condition" "$rel" \
  's.sub("        # branch before the release becomes public.\n'"$tap_if"'\n", "        # branch before the release becomes public.\n")'
mutate "tap step back on the tag name" "$rel" \
  's.sub("      - name: Generate the formula and open a tap pull request\n'"$tap_if"'\n", "      - name: Generate the formula and open a tap pull request\n        if: \${{ !contains(github.ref_name, %q[-]) }}\n")'
mutate "token check on another condition" "$rel" \
  's.sub("      - name: Check the tap token\n'"$tap_if"'\n", "      - name: Check the tap token\n        if: always()\n")'
mutate "no plan step id" "$rel" 's.sub("        id: plan\n", "")'
mutate "plan step runs another command" "$rel" 's.sub("          command: plan\n", "          command: check\n")'
mutate "plan step gets the tap token" "$rel" \
  's.sub("          command: plan\n", "          command: plan\n          tap-token: \${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}\n")'
mutate "plan step made conditional" "$rel" 's.sub("        id: plan\n", "        id: plan\n        if: always()\n")'
mutate "tap step renamed" "$rel" \
  's.sub("- name: Generate the formula and open a tap pull request", "- name: Generate the formula and open the tap pull request")'
mutate "CI on another Hephaestus" "$ci" \
  's.sub("magicdrive/hephaestus@e544acf59c79cbafa04a48002b0f30f91a02f8ba", "magicdrive/hephaestus@160990d32bbc83af702bde8a63f49ffcac32972c")'
mutate "Hephaestus pinned to a tag" "$rel" \
  's.sub("magicdrive/hephaestus@e544acf59c79cbafa04a48002b0f30f91a02f8ba", "magicdrive/hephaestus@v1.3.0")'
mutate "make publish on another Hephaestus" Makefile 's.sub(/^HEPHAESTUS_VERSION \?= v.*$/, "HEPHAESTUS_VERSION ?= v1.1.0")'
mutate "an action pin's version comment differs" "$ci" 's.sub(/(uses: magicdrive\/hephaestus@\h{40}) # v\S+/, "\\1 # v1.1.0")'
mutate "a release job without a timeout" "$rel" 's.sub(/\n    timeout-minutes: 30\n/, "\n")'
mutate "a CI job without a timeout" "$ci" 's.sub(/\n    timeout-minutes: 15\n/, "\n")'
mutate "the build job gets a secret" "$rel" \
  's.sub("          stages: archive,checksum\n", "          stages: archive,checksum\n          tap-token: \${{ secrets.HOMEBREW_TAP_GITHUB_TOKEN }}\n")'
mutate "no attestation" "$rel" 's.sub(/      - name: Attest build provenance\n.*?\n(?=      - name: Publish)/m, "")'

exit "$failed"
