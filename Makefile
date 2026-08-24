R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

MAKES_LOCAL_DIR ?= $(CURDIR)/.cache/local
YSD-VERSION := 0.1.2

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

version:
	@echo '$(YSD-VERSION)'

test: test-unit test-version test-release test-installer test-scripts

test-unit: $(YS) $(PERL)
	prove$(if $v, -v) test/*.t

test-version: $(YS)
	test "$$(bin/ysd --version)" = 'ysd $(YSD-VERSION)'

test-release: $(PERL)
	PERL='$(PERL)' test/release

test-installer:
	test/installer

test-scripts: $(SHELLCHECK)
	$(SHELLCHECK) \
	  util/release util/release-dist \
	  test/release test/installer \
	  www/docs/install

json-schema-suite:
	util/ysd-suite-roundtrip --fetch-only

suite-roundtrip:
	util/ysd-suite-roundtrip draft4

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
	test "$$('$(RELEASE-BUILD)/bin/linux_amd64/ysd' --version)" = \
	  'ysd $(YSD-VERSION)'
	go_bin=$$('$(GLOAT)' --which=go); \
	  go_root=$$("$$go_bin" env GOROOT); \
	  test "$$(env -i PATH='$(dir $(NODE)):/usr/bin:/bin' \
	    "$$go_root/lib/wasm/go_js_wasm_exec" \
	    '$(RELEASE-BUILD)/bin/js_wasm/ysd.wasm' --version)" = \
	    'ysd $(YSD-VERSION)'
	cd '$(DIST)' && sha256sum -c ysd-checksums.txt

release: $(GH) $(PERL)
	@$(if $(filter command line,$(origin VERSION)),,\
	  $(error VERSION is required on the command line))
	$Q PERL='$(PERL)' GH='$(GH)' \
	  '$(RELEASE)' release '$(VERSION)'

MAKES-CLEAN += .cache/release dist

serve publish:
	$(MAKE) -C www $@
