PREFIX=${HOME}/local
CURRENTDIR=$(shell pwd -L | perl -p -e 's/ /\\ /g')

all:
	@echo "make [install|uninstall|lint|test|test-release|snapshot|check-version TAG=vX.Y.Z|release-preflight TAG=vX.Y.Z|release-status TAG=vX.Y.Z]"
	@echo "make publish vX.Y.Z         release: man page check, preflight, confirm, tag, push, follow, verify"
	@echo "make publish-check vX.Y.Z   man page check + release preflight only (read-only)"
	@echo "make publish-status vX.Y.Z  what exists for a version (read-only)"
	@echo "make publish-watch vX.Y.Z   follow the release run of an already pushed tag"
	@echo "make publish-help           how publishing works"

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
# (https://github.com/magicdrive/hephaestus; HEPHAESTUS=hephaestus uses an
# installed one); releases are published by .github/workflows/release.yml on
# a tag push (docs/releasing.md).
# renovate: datasource=go depName=github.com/magicdrive/hephaestus
HEPHAESTUS_VERSION ?= v1.3.0
HEPHAESTUS ?= go run github.com/magicdrive/hephaestus@$(HEPHAESTUS_VERSION)
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
	scripts/test-publish-make.sh

.PHONY: all man install uninstall lint test snapshot check-version release-preflight release-status test-release

# ---------------------------------------------------------------------------
# Release with Hephaestus (its docs/publish.md; docs/releasing.md here):
#   make publish v1.2.3          (or VERSION=v1.2.3, or tag=v1.2.3)
#   make publish-check v1.2.3    man page check + preflight only
#   make publish-status v1.2.3   what exists for a version
#   make publish-watch v1.2.3    follow an already pushed tag
#   make publish-help
# The version given as a goal is a no-op goal (.DEFAULT). It reaches
# scripts/check-version.sh and hephaestus through the environment, never
# through a shell command line, and both validate it. YES=1 on the command
# line skips the prompt. The release workflow is the only publisher; publish
# only pushes the tag after its checks, then follows and verifies the run.
#
# Releases are cut from the release branch: the repository's default branch
# on GitHub (master), as no preflight.branch is set in hephaestus.yaml.
#
# The man page carries the release version, so publish and publish-check
# first require t.1 to name it (scripts/check-version.sh): a tag the release
# workflow would refuse is never pushed.
PUBLISH ?= $(HEPHAESTUS) publish
VERSION_CHECK ?= scripts/check-version.sh
PUBLISH_TARGETS = publish publish-check publish-status publish-watch publish-help

ifneq ($(filter $(PUBLISH_TARGETS),$(MAKECMDGOALS)),)
PUBLISH_GOAL := $(firstword $(MAKECMDGOALS))
PUBLISH_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ifeq ($(filter $(PUBLISH_TARGETS),$(PUBLISH_GOAL)),)
$(error publish targets come first and alone: make publish v1.2.3)
endif
ifneq ($(filter $(PUBLISH_TARGETS),$(PUBLISH_ARGS)),)
$(error give one publish target at a time)
endif
ifneq ($(word 2,$(PUBLISH_ARGS)),)
$(error one version is expected, got: $(PUBLISH_ARGS))
endif
ifeq ($(PUBLISH_GOAL),publish-help)
ifneq ($(PUBLISH_ARGS),)
$(error publish-help takes no version)
endif
endif
export HEPHAESTUS_PUBLISH_ARGS := $(PUBLISH_ARGS)
export HEPHAESTUS_PUBLISH_VERSION := $(if $(filter command line,$(origin VERSION)),$(VERSION))
export HEPHAESTUS_PUBLISH_TAG := $(if $(filter command line,$(origin tag)),$(tag))
PUBLISH_YES := $(if $(and $(filter command line,$(origin YES)),$(filter 1,$(YES))),-yes)
ifneq ($(PUBLISH_ARGS),)
ifeq ($(filter v0% v1% v2% v3% v4% v5% v6% v7% v8% v9% 0% 1% 2% 3% 4% 5% 6% 7% 8% 9%,$(PUBLISH_ARGS)),)
$(error "$(PUBLISH_ARGS)" is not a version: make $(PUBLISH_GOAL) v1.2.3)
endif
# The version goal has no rule of its own: it is the publish target's
# argument. (No other target may start with v<digit>.)
.DEFAULT:
	@:
endif
endif

.PHONY: publish publish-check publish-status publish-watch publish-help
publish:
	@$(VERSION_CHECK) --from-make
	@$(PUBLISH) publish -from-make $(PUBLISH_YES)
# Reports both the man page check and the preflight; an invalid or missing
# version (exit 2) stops before the preflight.
publish-check:
	@rc=0; $(VERSION_CHECK) --from-make || rc=$$?; \
	if [ "$$rc" -ge 2 ]; then exit "$$rc"; fi; \
	$(PUBLISH) check -from-make || exit $$?; \
	exit "$$rc"
publish-status:
	@$(PUBLISH) status -from-make
publish-watch:
	@$(PUBLISH) watch -from-make
publish-help:
	@$(PUBLISH) help
