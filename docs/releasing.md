# Releasing t

Releases are published by `.github/workflows/release.yml` when a `v*` tag is
pushed, with [Hephaestus](https://github.com/magicdrive/hephaestus)
(`hephaestus.yaml`). Nothing is compiled: `t` is a Bash script, packaged as
it is in the repository.

## What a release contains

| Asset | Contents |
| --- | --- |
| `t_<version>_darwin_amd64.tar.gz`, `t_<version>_darwin_arm64.tar.gz`, `t_<version>_linux_amd64.tar.gz`, `t_<version>_linux_arm64.tar.gz` | `t` (0755), `t.1`, `misc/completions/t-completion.sh`, `Makefile`, `README.md`, `LICENSE` — the same files in every archive, one archive per Homebrew platform |
| `t_checksums.txt` | SHA-256 of the four archives |

Every asset has a build provenance attestation. The source archives GitHub
attaches to every tag (`/archive/refs/tags/<tag>.tar.gz`) are unchanged, so
existing download URLs keep working. An unpacked archive installs with
`make install PREFIX=...` as a clone does.

For a stable version (`v1.2.0`) the workflow also opens a pull request on
[magicdrive/homebrew-tap](https://github.com/magicdrive/homebrew-tap) adding
or updating `t.rb` at the tap root. It is never merged automatically: review
and merge it. Prereleases (`v1.2.0-rc.1`) are published as GitHub
prereleases and never touch the tap; the tap token is not passed to them.

## One-time setup (repository settings)

| Item | Value |
| --- | --- |
| Environment `release` | Deployment restricted to **tags** `v*` (a tag policy, not a branch policy) |
| Secret in `release` | `HOMEBREW_TAP_GITHUB_TOKEN`: fine-grained token (or GitHub App token) with contents and pull-requests write on `magicdrive/homebrew-tap` only |
| Workflow permissions | Settings → Actions → General: "Read repository contents" (the workflows request what they need) |
| Rulesets (recommended) | `master`: require the `ci-gate` check, no force pushes or deletion; tags `v*`: no update or deletion |

## Cutting a release

1. Update the version in `t.1` (`.TH t 1 "<date>" "vX.Y.Z"`) and merge it.
   The release checks it: `make check-version TAG=vX.Y.Z`.
2. On an up-to-date, clean `master` whose CI is green:

   ```sh
   git tag -a v1.2.0 -m "v1.2.0"
   git push origin refs/tags/v1.2.0
   ```

3. `.github/workflows/release.yml` runs:
   1. **ci** — the complete CI at the tagged commit (`ci-gate`);
   2. **build** (read-only, no secrets) — tag and man page version check,
      `archive,checksum` with Hephaestus, `scripts/verify-dist.sh`, upload
      `dist/`;
   3. **release** (environment `release`) — verify `dist/` again; for a
      stable tag, a read-only rehearsal of the tap pull request with the tap
      token; provenance attestation; the GitHub release (draft, upload and
      verify every asset, then publish, with generated notes); for a stable
      tag, the formula and the tap pull request.
4. Review and merge the tap pull request.

A failed run can be re-run: the release stays a draft until every asset is
uploaded and verified, and every step skips what is already in place. Do not
move or delete a pushed tag; release the next version instead.

## Verifying a release

```sh
gh release download v1.2.0 --repo magicdrive/t --dir rel && cd rel
shasum -a 256 -c t_checksums.txt
for f in t_*; do
  gh attestation verify "$f" --repo magicdrive/t \
    --signer-workflow magicdrive/t/.github/workflows/release.yml \
    --source-ref refs/tags/v1.2.0 --deny-self-hosted-runners
done
```

## Locally

```sh
make lint                                  # bash -n, zsh -n, ShellCheck, man page
make test                                  # help, completion, tmux sessions
make snapshot HEPHAESTUS=/path/to/hephaestus   # archives into dist/
make check-version TAG=v1.2.0
```

CI (`.github/workflows/ci.yml`) also installs the generated formula from
the local archives with the real Homebrew on macOS and Linux
(`scripts/homebrew-test.sh`).
