# Install the YAMLSchema command and source repository.
#
# Usage:
#   make -f install.mk install [PREFIX=dir] [VERSION=x.y.z]

R := https://github.com/makeplus/makes
PREFIX ?= $(if $(filter 0,$(shell id -u)),/usr/local,$(HOME)/.local)
PREFIX-PATH := $(abspath $(PREFIX))
M := $(or $(MAKES_REPO_DIR),$(PREFIX-PATH)/share/makes)

ifeq (,$(MAKES_REPO_DIR))
$(shell mkdir -p '$(PREFIX-PATH)/share')
$(shell if [ -d '$(M)/.git' ]; then \
  git -C '$(M)' pull -q --ff-only; \
else \
  git clone -q --depth=1 '$(R)' '$(M)'; \
fi)
endif

MAKES-QUIET := 1
override MAKES_LOCAL_DIR := $(PREFIX-PATH)/share
include $(M)/init.mk

ifneq (,$(VERSION))
YAMLSCHEMA-VERSION := $(VERSION)
endif
include $(M)/yamlschema.mk

YAMLSCHEMA-REPO ?= https://github.com/yaml/yamlschema
YAMLSCHEMA-REPO-DIR := $(PREFIX-PATH)/share/yamlschema
YAMLSCHEMA-TAG := v$(YAMLSCHEMA-VERSION)
YSD-INSTALL := $(PREFIX-PATH)/bin/$(YAMLSCHEMA-EXE)

FORCE:

$(YAMLSCHEMA-REPO-DIR)/.git:
	@mkdir -p '$(PREFIX-PATH)/share'
	@git clone -q '$(YAMLSCHEMA-REPO)' '$(YAMLSCHEMA-REPO-DIR)'

yamlschema-repo-install: $(YAMLSCHEMA-REPO-DIR)/.git FORCE
	@test "$$(git -C '$(YAMLSCHEMA-REPO-DIR)' remote get-url origin)" = \
	  '$(YAMLSCHEMA-REPO)' || { \
	    echo 'YAMLSchema install: repository origin does not match' >&2; \
	    exit 1; \
	  }
	@test -z "$$(git -C '$(YAMLSCHEMA-REPO-DIR)' status --porcelain)" || { \
	    echo 'YAMLSchema install: repository checkout has local changes' >&2; \
	    exit 1; \
	  }
	@git -C '$(YAMLSCHEMA-REPO-DIR)' fetch -q origin \
	  'refs/tags/$(YAMLSCHEMA-TAG):refs/tags/$(YAMLSCHEMA-TAG)'
	@git -C '$(YAMLSCHEMA-REPO-DIR)' checkout -q --detach \
	  '$(YAMLSCHEMA-TAG)'
	@test "$$(git -C '$(YAMLSCHEMA-REPO-DIR)' rev-parse HEAD)" = \
	  "$$(git -C '$(YAMLSCHEMA-REPO-DIR)' rev-list -n 1 \
	    '$(YAMLSCHEMA-TAG)')"

$(YSD-INSTALL): $(YSD) yamlschema-repo-install FORCE
	@mkdir -p '$(PREFIX-PATH)/bin'
	@temporary='$@.tmp.$$$$'; \
	  trap 'rm -f "$$temporary"' EXIT; \
	  cp '$(YSD)' "$$temporary"; \
	  chmod 0755 "$$temporary"; \
	  test "$$($$temporary --version)" = \
	    'ysd $(YAMLSCHEMA-VERSION)'; \
	  mv -f "$$temporary" '$@'; \
	  trap - EXIT

install: $(YSD-INSTALL) FORCE
	@printf '%s\n' '$(YSD-INSTALL)'
