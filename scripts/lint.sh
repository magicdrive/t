#!/usr/bin/env bash
# Static checks for the shipped files. Run from the repository root.
#
# ShellCheck gates on errors. Findings present before CI existed are
# excluded explicitly, with the reason, so that any new error fails:
#   t                  SC2068  unquoted $@ passes tmux options through word
#                              splitting; quoting it changes behavior and is
#                              left to a separate change.
#   t-completion.sh    SC2296  zsh-only ${(@f)...} in the zsh branch of a file
#                              that serves both bash and zsh.
# Warnings are printed but do not fail.
set -euo pipefail

status=0
run() { echo "+ $*"; "$@" || status=1; }

run bash -n t
run bash -n misc/completions/t-completion.sh
if command -v zsh >/dev/null; then
  run zsh -n misc/completions/t-completion.sh
else
  echo "zsh not installed: skipping zsh -n"
fi

run shellcheck --shell=bash --severity=error --exclude=SC2068 t
run shellcheck --shell=bash --severity=error --exclude=SC2296 misc/completions/t-completion.sh
shellcheck --shell=bash --severity=warning t misc/completions/t-completion.sh || echo "(warnings above are not gating)"

for f in scripts/*.sh; do
  run shellcheck --shell=bash "$f"
done

if command -v mandoc >/dev/null; then
  run mandoc -T lint -W error t.1
else
  echo "mandoc not installed: skipping man page lint"
fi

exit "$status"
