#!/usr/bin/env bash
# Failure-injection test of the "Installed files" step of
# .github/workflows/tap-install.yml: the step runs as the runner runs it
# (`bash -e`, the default shell) against a fake Homebrew prefix, with brew and
# gh replaced by stubs, and must fail whenever one of its checks fails
# (`a && b` does not stop a `set -e` script when `a` fails).
# Usage: scripts/test-tap-install.sh   (make test-release)
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
step="$tmp/step.sh"
ruby -ryaml -e '
  w = YAML.load_file(".github/workflows/tap-install.yml")
  s = w["jobs"]["install"]["steps"].find { |x| x["name"] == "Installed files" } or abort("no step named Installed files")
  abort("the step sets shell: #{s["shell"]}; this test runs bash -e") if s["shell"]
  File.write(ARGV[0], s["run"])' "$step"

failed=0
# case NAME WANT(ok|fail) HELP-EXIT HELP-TEXT
case_() {
  local name="$1" want="$2" help_exit="$3" help_text="$4" dir rc=0
  dir="$tmp/$RANDOM$RANDOM"
  local p="$dir/prefix" stubs="$dir/stubs"
  mkdir -p "$p/bin" "$p/share/man/man1" "$p/etc/bash_completion.d" "$p/share/t" "$stubs" "$dir/runner"
  printf '#!/bin/sh\necho "%s"\nexit %s\n' "$help_text" "$help_exit" > "$p/bin/t"
  chmod +x "$p/bin/t"
  echo '.TH t 1 "2026-01-01" "v9.9.9"' > "$p/share/man/man1/t.1"
  echo '_t_complete() { :; }; complete -F _t_complete t' > "$p/share/t/t-completion.sh"
  ln -s "$p/share/t/t-completion.sh" "$p/etc/bash_completion.d/t"
  cat > "$stubs/brew" <<EOF
#!/bin/sh
case "\$*" in
--prefix) echo "$p" ;;
"list --versions t") echo "t 9.9.9" ;;
*) echo "brew stub: \$*" >&2; exit 1 ;;
esac
EOF
  # gh release download v9.9.9 ... --dir DIR: the release archive of the
  # files installed above.
  cat > "$stubs/gh" <<EOF
#!/bin/sh
d=""; while [ \$# -gt 0 ]; do [ "\$1" = --dir ] && d="\$2"; shift; done
mkdir -p "\$d" "$dir/a/misc/completions"
cp "$p/bin/t" "$p/share/man/man1/t.1" "$dir/a/"
cp "$p/share/t/t-completion.sh" "$dir/a/misc/completions/"
tar -czf "\$d/t_9.9.9_linux_amd64.tar.gz" -C "$dir/a" t t.1 misc
EOF
  chmod +x "$stubs/brew" "$stubs/gh"
  (cd "$dir" && PATH="$stubs:$PATH" RUNNER_TEMP="$dir/runner" bash -e "$step") >"$dir/out" 2>&1 || rc=$?
  if [[ "$want" == ok && "$rc" -eq 0 ]] || [[ "$want" == fail && "$rc" -ne 0 ]]; then
    echo "ok   $name (exit $rc)"
  else
    echo "FAIL $name: exit $rc, want $want"; sed 's/^/     | /' "$dir/out"; failed=1
  fi
}

case_ "t --help exits 1 with the usage" ok 1 "USAGE: t [options]"
case_ "t --help exits 0" fail 0 "USAGE: t [options]"
case_ "t --help exits 2" fail 2 "USAGE: t [options]"
case_ "t --help prints no usage" fail 1 "t: something else"

if (( failed )); then echo "test-tap-install: FAILED"; exit 1; fi
echo "test-tap-install: ok"
