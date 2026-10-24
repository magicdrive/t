#!/usr/bin/env bash
# Verifies a release dist directory before anything is published: every
# platform archive exists with exactly the declared files and modes, the
# checksum file matches, and the packaged t runs.
# Usage: scripts/verify-dist.sh <dist> <version>   (version without "v")
set -euo pipefail
export LC_ALL=C
dist="${1:?usage: verify-dist.sh <dist> <version>}"
version="${2:?usage: verify-dist.sh <dist> <version>}"
cd "$dist"

sums=t_checksums.txt
[[ -f "$sums" ]] || { echo "missing $sums"; exit 1; }
if command -v sha256sum >/dev/null; then sha256sum -c "$sums"; else shasum -a 256 -c "$sums"; fi

want="LICENSE Makefile README.md misc/ misc/completions/ misc/completions/t-completion.sh t t.1 "
count=0
for os in darwin linux; do
  for arch in amd64 arm64; do
    f="t_${version}_${os}_${arch}.tar.gz"
    [[ -f "$f" ]] || { echo "missing $f"; exit 1; }
    got="$(tar -tzf "$f" | sort | tr '\n' ' ')"
    [[ "$got" == "$want" ]] || { echo "$f: contents '$got', want '$want'"; exit 1; }
    verbose="$(tar -tvzf "$f")"
    grep -qE -- '^-rwxr-xr-x .* t$' <<<"$verbose" || { echo "$f: t is not 0755"; exit 1; }
    grep -qE -- '^-rw-r--r-- .* t\.1$' <<<"$verbose" || { echo "$f: t.1 is not 0644"; exit 1; }
    grep -q "  $f\$" "$sums" || { echo "$f missing from $sums"; exit 1; }
    count=$((count + 1))
  done
done
[[ $count -eq 4 ]]
[[ "$(wc -l < "$sums" | tr -d ' ')" -eq 4 ]] || { echo "$sums must list exactly the 4 archives"; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
tar -xzf "t_${version}_linux_amd64.tar.gz" -C "$tmp"
set +e; out="$("$tmp/t" --help 2>&1)"; code=$?; set -e
if [[ $code -ne 1 ]] || ! grep -q '^USAGE:' <<<"$out"; then
  echo "packaged t --help failed ($code)"; exit 1
fi
echo "dist OK: $count archives"
