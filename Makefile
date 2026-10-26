PREFIX=${HOME}/local
CURRENTDIR=$(shell pwd -L | perl -p -e 's/ /\\ /g')

all:
	@echo "make [install|uninstall|lint|test|test-release|snapshot|check-version TAG=vX.Y.Z|release-preflight TAG=vX.Y.Z|release-status TAG=vX.Y.Z]"

man:
	[ -e $(shell which md2man-roff) ] && md2man-roff $(CURRENTDIR)/README.md > $(CURRENTDIR)/t.1

install:
	mkdir -p $(PREFIX)/bin/ $(PREFIX)/share/man/man1/
	cp -af $(CURRENTDIR)/t $(PREFIX)/bin/
	cp -af $(CURRENTDIR)/t.1 $(PREFIX)/share/man/man1/

uninstall:
	rm -f $(PREFIX)/bin/t
	rm -f  $(PREFIX)/share/man/man1/t.1


# Static checks: bash -n, zsh -n, ShellCheck, man page (scripts/lint.sh)
lint:
	scripts/lint.sh

# Behavior checks: help, completion, tmux sessions (scripts/smoke.sh)
test:
	scripts/smoke.sh

# Release archives into dist/ without a tag, with Hephaestus
# (https://github.com/magicdrive/hephaestus); releases are published by
# .github/workflows/release.yml on a tag push (docs/releasing.md).
HEPHAESTUS ?= hephaestus
snapshot:
	$(HEPHAESTUS) run --snapshot --fresh --stages archive,checksum
	scripts/verify-dist.sh dist 0.0.0-SNAPSHOT

# Check a release tag against the man page before tagging: make check-version TAG=v1.2.0
check-version:
	scripts/check-version.sh $(TAG)

# Read-only checks before pushing a release tag (git, CI, environment,
# rulesets, man page, tap): make release-preflight TAG=v1.2.0-rc.1
release-preflight:
	scripts/release-preflight.sh $(TAG)

# Read-only verification of a published release with Hephaestus: assets,
# checksums, attestations, the release run and the tap pull request
# (hephaestus publish status): make release-status TAG=v1.2.1
release-status:
	$(HEPHAESTUS) publish status $(TAG)

# Tests of the release rules and of the release workflow's structure (the
# structure checks, and that they catch each way of weakening the release)
test-release:
	scripts/test-release-rules.sh
	ruby scripts/check-workflows.rb
	scripts/test-check-workflows.sh

.PHONY: all man install uninstall lint test snapshot check-version release-preflight release-status test-release
