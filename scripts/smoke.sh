#!/usr/bin/env bash
# Behavior checks for t and its completion script, without attaching to a
# terminal. Needs tmux; uses a private tmux socket so no user session is
# touched. Run from the repository root (or pass the t to test as $1).
set -euo pipefail

t="$(cd "$(dirname "${1:-./t}")" && pwd)/$(basename "${1:-./t}")"
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== help"
for flag in -h --help; do
  set +e; out="$("$t" "$flag" 2>&1)"; code=$?; set -e
  [[ $code -eq 1 ]] || fail "$flag exited $code, want 1"
  grep -q '^USAGE:' <<<"$out" || fail "$flag printed no USAGE"
done

echo "== bash completion"
bash --norc --noprofile -c "source misc/completions/t-completion.sh; complete -p t" | grep -q '_t_complete t' \
  || fail "bash completion not registered"
if command -v zsh >/dev/null; then
  echo "== zsh completion"
  zsh -f -c 'autoload -Uz compinit && compinit -u -D; source misc/completions/t-completion.sh; [[ ${_comps[t]} == _t_complete ]]' \
    || fail "zsh completion not registered"
fi

command -v tmux >/dev/null || { echo "tmux not installed: skipping session checks"; exit 0; }

echo "== sessions on a private tmux server"
tmpdir="$(mktemp -d)"
export TMUX_TMPDIR="$tmpdir"
unset TMUX
cleanup() { tmux kill-server >/dev/null 2>&1 || true; rm -rf "$tmpdir"; }
trap cleanup EXIT
tmux new-session -d -s heph-smoke
"$t" -l | grep -q '^heph-smoke:' || fail "t -l does not list the session"
"$t" --list | grep -q '^heph-smoke:' || fail "t --list does not list the session"
set +e; "$t" -k heph-smoke; set -e
tmux has-session -t heph-smoke 2>/dev/null && fail "t -k did not kill the session"
echo "smoke OK"
