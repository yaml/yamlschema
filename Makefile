R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

MAKES_LOCAL_DIR ?= $(CURDIR)/.cache/local
YSD-VERSION := 0.1.5

include $M/init.mk
include $M/gh.mk
include $M/gloat.mk
include $M/node.mk
include $M/perl.mk
include $M/shellcheck.mk
include $M/yamlscript.mk
include $M/clean.mk
include $M/shell.mk

RELEASE := $(CURDIR)/util/release
RELEASE-DIST := $(CURDIR)/util/release-dist
DIST := $(CURDIR)/dist
RELEASE-BUILD := $(CURDIR)/.cache/release
RELEASE-SMOKE-INPUT := $(CURDIR)/test/files/person.schema.json
PREFIX ?= $(if $(filter 0,$(shell id -u)),/usr/local,$(HOME)/.local)
PREFIX-PATH := $(abspath $(PREFIX))
YAMLSCHEMA-INSTALL := $(PREFIX-PATH)/share/yamlschema
YSD-INSTALL := $(PREFIX-PATH)/bin/ysd

version:
	@echo '$(YSD-VERSION)'

build: ysd

ysd: bin/ysd $(GLOAT)
	$(GLOAT) '$<' \
	  --out='$@' --force --quiet \
	  --module=github.com/yaml/yamlschema

install: build
	@set -eu; \
	  head=$$(git rev-parse HEAD); \
	  origin=$$(git remote get-url origin 2>/dev/null || :); \
	  repo='$(YAMLSCHEMA-INSTALL)'; \
	  mkdir -p '$(PREFIX-PATH)/share'; \
	  if test -d "$$repo/.git" && \
	      test "$$(cd "$$repo" && pwd -P)" = '$(CURDIR)'; then \
	    :; \
	  elif test -e "$$repo"; then \
	    test -d "$$repo/.git" || { \
	      echo 'YAMLSchema install: destination is not a Git repo' >&2; \
	      exit 1; \
	    }; \
	    test -z "$$(git -C "$$repo" status --porcelain)" || { \
	      echo 'YAMLSchema install: destination has local changes' >&2; \
	      exit 1; \
	    }; \
	    git -C "$$repo" fetch -q '$(CURDIR)' "$$head"; \
	    git -C "$$repo" checkout -q --detach FETCH_HEAD; \
	  else \
	    git clone -q --no-checkout '$(CURDIR)' "$$repo"; \
	    git -C "$$repo" checkout -q --detach "$$head"; \
	  fi; \
	  if test -n "$$origin" && test "$$repo" != '$(CURDIR)'; then \
	    git -C "$$repo" remote set-url origin "$$origin"; \
	  fi; \
	  test "$$(git -C "$$repo" rev-parse HEAD)" = "$$head"
	@install -d '$(PREFIX-PATH)/bin'
	@temporary='$(YSD-INSTALL).tmp.$$$$'; \
	  trap 'rm -f "$$temporary"' EXIT; \
	  install -m 0755 ysd "$$temporary"; \
	  test "$$($$temporary --version)" = 'ysd $(YSD-VERSION)'; \
	  mv -f "$$temporary" '$(YSD-INSTALL)'; \
	  trap - EXIT
	@printf 'Installed YAMLSchema to %s\n' '$(YSD-INSTALL)'
	@printf '%s\n' \
	  'To enable tab completion and man pages in future shells, add:'
	@printf '  source %s/.rc\n' '$(YAMLSCHEMA-INSTALL)'

test: \
  test-unit test-version test-release test-installer test-install \
  test-upgrade test-man test-scripts

test-unit: $(YS) $(PERL)
	prove$(if $v, -v) test/*.t

test-version: $(YS)
	test "$$(bin/ysd --version)" = 'ysd $(YSD-VERSION)'

test-release: $(PERL)
	PERL='$(PERL)' test/release

test-installer:
	test/installer

test-install: build
	@temporary=$$(mktemp -d); \
	  trap 'rm -rf -- "$$temporary"' EXIT; \
	  home="$$temporary/home"; \
	  if test "$$(id -u)" = 0; then \
	    default=/usr/local; \
	  else \
	    default="$$home/.local"; \
	  fi; \
	  actual=$$(HOME="$$home" $(MAKE) --no-print-directory -s \
	    --eval='print-prefix:;@printf "%s\n" "$$(PREFIX-PATH)"' \
	    print-prefix); \
	  test "$$actual" = "$$default"; \
	  prefix="$$temporary/prefix"; \
	  output=$$($(MAKE) --no-print-directory install PREFIX="$$prefix"); \
	  expected=$$(printf '%s\n' \
	    "Installed YAMLSchema to $$prefix/bin/ysd" \
	    'To enable tab completion and man pages in future shells, add:' \
	    "  source $$prefix/share/yamlschema/.rc"); \
	  test "$$output" = "$$expected"; \
	  test "$$($$prefix/bin/ysd --version)" = 'ysd $(YSD-VERSION)'; \
	  test -f "$$prefix/share/yamlschema/.rc"; \
	  test -f "$$prefix/share/yamlschema/man/man1/ysd.1"; \
	  test -f "$$prefix/share/yamlschema/share/complete.bash"; \
	  test "$$(git -C "$$prefix/share/yamlschema" rev-parse HEAD)" = \
	    "$$(git rev-parse HEAD)"; \
	  test "$$(git -C "$$prefix/share/yamlschema" remote get-url origin)" = \
	    "$$(git remote get-url origin)"; \
	  test -z "$$(git -C "$$prefix/share/yamlschema" status --short)"; \
	  $(MAKE) --no-print-directory install PREFIX="$$prefix" >/dev/null; \
	  touch "$$prefix/share/yamlschema/local-change"; \
	  if $(MAKE) --no-print-directory install PREFIX="$$prefix" \
	      >"$$temporary/dirty.out" 2>&1; then \
	    echo 'source install accepted local changes' >&2; \
	    exit 1; \
	  fi; \
	  grep -Fqx \
	    'YAMLSchema install: destination has local changes' \
	    "$$temporary/dirty.out"
	@echo 'Source installation checks passed'

test-upgrade: build $(YS)
	PATH='$(dir $(YS)):$(PATH)' test/upgrade
	YSD='$(CURDIR)/ysd' TEST_UPGRADE_ERRORS=0 test/upgrade

test-man:
	$(MAKE) -C man test

test-scripts: $(SHELLCHECK) $(YS)
	$(SHELLCHECK) \
	  .rc \
	  share/complete.bash \
	  util/release util/release-dist \
	  test/release test/installer test/upgrade \
	  www/docs/install
	zsh -n share/complete.zsh
	fish -n share/complete.fish

json-schema-suite:
	util/ysd-suite-roundtrip --fetch-only

suite-roundtrip:
	util/ysd-suite-roundtrip draft4

.PHONY: man
man:
	$(MAKE) -C man

update: man

release-prep: $(PERL)
	@$(if $(filter command line,$(origin VERSION)),,\
	  $(error VERSION is required on the command line))
	$Q PERL='$(PERL)' '$(RELEASE)' prepare '$(VERSION)'

release-dist: $(GLOAT) $(PERL)
	@$(if $(filter command line,$(origin VERSION)),,\
	  $(error VERSION is required on the command line))
	$Q PERL='$(PERL)' '$(RELEASE-DIST)' \
	  '$(VERSION)' '$(GLOAT)' '$(CURDIR)' \
	  '$(DIST)' '$(RELEASE-BUILD)' '$(YSD-VERSION)'

release-smoke: release-dist $(NODE)
	for archive in \
	    ysd-$(VERSION)-linux_amd64.tar.gz \
	    ysd-$(VERSION)-linux_arm64.tar.gz \
	    ysd-$(VERSION)-darwin_arm64.tar.gz \
	    ysd-$(VERSION)-windows_amd64.zip \
	    ysd-$(VERSION)-windows_arm64.zip \
	    ysd-$(VERSION)-js_wasm.tar.gz; do \
	  test -f '$(DIST)'/$$archive; \
	done
	native='$(RELEASE-BUILD)/bin/linux_amd64/ysd'; \
	  test "$$($$native --version)" = \
	  'ysd $(YSD-VERSION)'
	native='$(RELEASE-BUILD)/bin/linux_amd64/ysd'; \
	  output=$$("$$native" '$(RELEASE-SMOKE-INPUT)'); \
	  printf '%s\n' "$$output" | grep -Fx '.title: Person'; \
	  printf '%s\n' "$$output" | grep -Fx 'name: +Str'
	go_bin=$$('$(GLOAT)' --which=go); \
	  go_root=$$("$$go_bin" env GOROOT); \
	  wasm_exec="$$go_root/lib/wasm/wasm_exec.js"; \
	  wasm='$(RELEASE-BUILD)/bin/js_wasm/ysd.wasm'; \
	  output=$$('$(NODE)' test/wasm-smoke.js \
	    "$$wasm_exec" "$$wasm" '$(RELEASE-SMOKE-INPUT)'); \
	  printf '%s\n' "$$output" | grep -Fx '.title: Person'; \
	  printf '%s\n' "$$output" | grep -Fx 'name: +Str'
	cd '$(DIST)' && sha256sum -c ysd-checksums.txt

release: $(GH) $(PERL)
	@$(if $(filter command line,$(origin VERSION)),,\
	  $(error VERSION is required on the command line))
	$Q RELEASE_BRANCH='$(RELEASE_BRANCH)' \
	  PERL='$(PERL)' GH='$(GH)' \
	  '$(RELEASE)' release '$(VERSION)'

MAKES-CLEAN += .cache/man-test .cache/release dist ysd

serve publish:
	$(MAKE) -C www $@

clean::
	$(MAKE) -C www $@

realclean::
	$(MAKE) -C www $@

distclean::
	$(MAKE) -C www $@
