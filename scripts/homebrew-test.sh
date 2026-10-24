#!/usr/bin/env bash
# Installs the generated formula from the local archives with the real
# Homebrew, in a throw-away tap: brew audit --strict, brew install, brew test,
# the installed files, brew uninstall. Removes everything it created.
# Usage: scripts/homebrew-test.sh <dist> <version>   (after the formula stage)
set -euo pipefail
dist="$(cd "${1:?usage: homebrew-test.sh <dist> <version>}" && pwd)"
version="${2:?usage: homebrew-test.sh <dist> <version>}"
tap="t-ci/t$RANDOM$RANDOM"

export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ANALYTICS=1 \
  HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
cleanup() {
  set +e
  brew uninstall --force "$tap/t" >/dev/null 2>&1
  brew untap --force "$tap" >/dev/null 2>&1
}
trap cleanup EXIT

# One explicit update: dependencies (tmux) are poured from bottles described
# by the current formula API, which an outdated Homebrew may not read.
brew update --quiet

brew tap-new --no-git "$tap" >/dev/null
tapdir="$(brew --repository "$tap")"
formula="$tapdir/Formula/t.rb"
# The formula downloads from the release; point it at the local archives.
sed "s|https://github.com/magicdrive/t/releases/download/v${version}/|file://${dist}/|" \
  "$dist/homebrew/t.rb" > "$formula"
grep -q "file://${dist}/t_${version}_" "$formula" || { echo "URLs were not rewritten"; exit 1; }
cat "$formula"

brew style "$tap/t"
brew audit --strict --formula "$tap/t"
brew install --formula "$tap/t"
brew test "$tap/t"

prefix="$(brew --prefix)"
[[ -x "$prefix/bin/t" ]] || { echo "bin/t missing"; exit 1; }
[[ -f "$prefix/share/man/man1/t.1" ]] || { echo "man page missing"; exit 1; }
[[ -f "$prefix/etc/bash_completion.d/t" ]] || { echo "bash completion missing"; exit 1; }
[[ -f "$prefix/share/t/t-completion.sh" ]] || { echo "completion script missing in pkgshare"; exit 1; }
# The rewritten file:// URLs no longer carry /download/v<version>/, from
# which Homebrew reads the version, so look the keg up by its opt link.
cmp "$(brew --prefix "$tap/t")/bin/t" "$(dirname "$0")/../t" || { echo "installed t differs from the source"; exit 1; }
brew uninstall --formula "$tap/t"
[[ ! -e "$prefix/bin/t" ]] || { echo "bin/t left after uninstall"; exit 1; }
echo "homebrew OK"
