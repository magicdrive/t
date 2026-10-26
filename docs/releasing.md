# Releasing t

Releases are published by `.github/workflows/release.yml` when a `v*` tag is
pushed, with [Hephaestus](https://github.com/magicdrive/hephaestus)
(`hephaestus.yaml`; the action pinned to the commit of v1.2.0, the same in
`ci.yml` and `release.yml`). Nothing is compiled: `t` is a Bash script, packaged as
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
| Environment `release` | Deployment restricted to **tags** `v*` only: a tag policy, no branch policy |
| Secret in `release` | `HOMEBREW_TAP_GITHUB_TOKEN`: fine-grained token (or GitHub App token) with contents and pull-requests write on `magicdrive/homebrew-tap` only |
| Workflow permissions | Settings → Actions → General: "Read repository contents and packages permissions"; "Allow GitHub Actions to create and approve pull requests" off (the tap pull request is opened with the tap token, not `GITHUB_TOKEN`) |
| Ruleset on `master` | Active: pull request required, `ci-gate` required, no force pushes, no deletion — [settings/ruleset-protect-master.json](settings/ruleset-protect-master.json) |
| Ruleset on tags `v*` | Active: no update, no deletion; creation allowed — [settings/ruleset-protect-release-tags.json](settings/ruleset-protect-release-tags.json) |

`make release-preflight TAG=...` checks every row it can read (secret names
only, never values).

Changing the environment policy in the UI: Settings → Environments →
`release` → Deployment branches and tags: remove the branch rule `v*`, add a
rule of type **Tag** with pattern `v*`. With the API:

```sh
gh api repos/magicdrive/t/environments/release/deployment-branch-policies --jq '.branch_policies[] | [.id, .name, .type]'
gh api --method DELETE repos/magicdrive/t/environments/release/deployment-branch-policies/<id of the branch v* policy>
gh api --method POST repos/magicdrive/t/environments/release/deployment-branch-policies -f name='v*' -f type=tag
```

Rulesets with the API:

```sh
gh api --method POST repos/magicdrive/t/rulesets --input docs/settings/ruleset-protect-master.json
gh api --method POST repos/magicdrive/t/rulesets --input docs/settings/ruleset-protect-release-tags.json
```

## Versions

Tags are `vMAJOR.MINOR.PATCH[-PRERELEASE]` (SemVer 2.0.0, no build metadata,
no leading zeros), each newer than the latest released `vX.Y.Z`. The man
page carries the release version **without** the pre-release part: `t.1`
says `v1.2.0` for `v1.2.0-rc.1`, `v1.2.0-rc.2` and `v1.2.0`. A release
candidate's commit can therefore become the stable release unchanged, and a
stable tag never ships a man page naming another version. The build job
enforces it (`scripts/check-version.sh`; `make check-version TAG=...`).

## Cutting a release

1. Set the version in `t.1` (`.TH t 1 "YYYY-MM-DD" "vX.Y.Z" ...`) and merge
   it.
2. On an up-to-date, clean `master` whose CI is green, run the read-only
   checks:

   ```sh
   make publish-check v1.2.0-rc.1
   ```

   It runs the man page check (`scripts/check-version.sh`), then the
   preflight of [`hephaestus publish`](https://github.com/magicdrive/hephaestus/blob/v1.3.0/docs/publish.md)
   (`make` runs the pinned `go run github.com/magicdrive/hephaestus@$(HEPHAESTUS_VERSION)`;
   Go is needed, `HEPHAESTUS=hephaestus` uses an installed one). The release
   branch is the repository's default branch on GitHub, `master`
   (`hephaestus.yaml` sets no `preflight.branch`); the preflight prints it as
   `default branch` and `release branch`. It checks: on `master`, clean
   worktree, `HEAD` = `origin/master` = `master` on GitHub; the tag exists
   neither locally nor on `origin`; `ci.yml` succeeded on exactly this commit
   on `master`; `release.yml` is active; environment `release` deploys only
   from matching tags; active rulesets protect `v*` tags (no update or
   deletion, creation allowed) and require `ci-gate` on `master`; no release
   or draft exists for the tag; for a stable tag also the tap token secret
   (by name), the tap's layout and that no `t-X.Y.Z` branch or pull request
   exists yet; and `hephaestus preflight --strict`.
   `make release-preflight TAG=v1.2.0-rc.1` runs this repository's own,
   equivalent checks, and also that the tag is newer than the latest
   release.
3. Tag and push (the only release trigger; a pushed tag is never moved or
   deleted):

   ```sh
   make publish v1.2.0-rc.1        # YES=1 confirms without the prompt
   ```

   It repeats the man page check and the preflight, asks, creates an
   annotated tag at the checked commit, checks `master` (on `origin` and on
   GitHub) and the remote tag again, pushes exactly that tag (never forced),
   then follows the release run below and verifies what it published. If
   monitoring stops, `make publish-watch v1.2.0-rc.1` resumes and
   `make publish-status v1.2.0-rc.1` shows where it stands. By hand, the same
   tag push is:

   ```sh
   git tag -a v1.2.0-rc.1 -m "v1.2.0-rc.1"
   git push origin refs/tags/v1.2.0-rc.1
   ```

4. `.github/workflows/release.yml` runs:
   1. **ci** — the complete CI at the tagged commit (`ci-gate`);
   2. **build** (read-only, no secrets) — tag and man page version check,
      `archive,checksum` with Hephaestus, `scripts/verify-dist.sh`, upload
      `dist/`;
   3. **release** (environment `release`) — verify `dist/` again; the
      release plan (the action's `plan` command: the tap is `publish` for a
      stable tag, `skip` for a prerelease, and a prerelease that would update
      the tap is refused); when the plan publishes the tap, a read-only
      rehearsal of the tap pull request with the tap token; provenance
      attestation; the GitHub release (draft, upload and verify every asset,
      then publish, with generated notes); when the plan publishes the tap,
      the formula and the tap pull request.
5. For a stable tag, review and merge the tap pull request.

A failed run can be re-run: the release stays a draft until every asset is
uploaded and verified, and every step skips what is already in place. Do not
move or delete a pushed tag; release the next version (e.g. `-rc.2`)
instead.

## Verifying a release

`make publish-status v1.2.1` (or `make release-status TAG=v1.2.1`; both run
`hephaestus publish status`, read-only)
checks the published release: the release run, the assets, the checksums,
every attestation, the tap steps and the formula pull request. By hand:

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
make snapshot                              # archives into dist/ (the pinned Hephaestus; needs Go)
make check-version TAG=v1.2.0
make publish-check v1.2.0-rc.1             # read-only: man page check + publish preflight
make publish v1.2.0-rc.1                   # the release (tag push), then follow and verify
make publish-status v1.2.1                 # read-only; a published release
make release-preflight TAG=v1.2.0-rc.1      # read-only; needs gh and jq
make test-release                          # release rules, workflow structure, make publish wiring
```

`HEPHAESTUS_VERSION` in the Makefile pins the Hephaestus the `make` targets
run, the same release as the action in the workflows.

CI (`.github/workflows/ci.yml`) also installs the generated formula from
the local archives with the real Homebrew on macOS and Linux
(`scripts/homebrew-test.sh`).
