R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk

GLOAT-VERSION := 0.1.78
NODE-VERSION := 26.7.0

LOCAL-GLOAT-DIR := $(or \
  $(if $(wildcard ../../gloat/bin/gloat),../../gloat), \
  $(if $(wildcard ../../../bin/gloat),../../..))

ifneq (,$(GLOAT_ROOT))
GLOAT-DIR ?= $(GLOAT_ROOT)
else ifneq (,$(LOCAL-GLOAT-DIR))
GLOAT-DIR ?= $(abspath $(LOCAL-GLOAT-DIR))
endif

include $M/gloat.mk
include $M/node.mk
include $M/python.mk
include $M/clean.mk
include $M/shell.mk

export UV_CACHE_DIR := $(CURDIR)/.cache/uv

REPO ?= git@github.com:yaml/yamlschema
SERVE-HOST ?= localhost
SERVE-PORT ?= 8000

SITE := site
EXAMPLE-SOURCES := $(wildcard src/examples/*)
EXAMPLE-FILES := $(patsubst src/examples/%,$(SITE)/examples/%,\
  $(EXAMPLE-SOURCES))
WASM := $(SITE)/ysc.wasm
WASM-EXEC := $(SITE)/wasm_exec.js
YAMLSCRIPT-DIR := ../../yamlscript
LOCAL-YS := $(wildcard $(YAMLSCRIPT-DIR)/ys/bin/ys)
GLOAT-ENV := $(if $(LOCAL-YS),GLOAT_YS=$(abspath $(LOCAL-YS)))

build: $(SITE)/index.html $(SITE)/app.js $(SITE)/json.js \
  $(SITE)/schema-worker.js $(SITE)/roundtrip-worker.js \
  $(SITE)/unified-diff.js $(SITE)/style.css $(SITE)/values.ysd.yaml \
  $(EXAMPLE-FILES) $(WASM-EXEC) $(WASM)

test: build $(NODE)
	cd $(SITE) && $(NODE) ../test/smoke.mjs

serve: build $(PYTHON)
	@printf '\nYAMLSchema: http://$(SERVE-HOST):$(SERVE-PORT)/\n\n'
	cd $(SITE) && $(PYTHON) -m http.server $(SERVE-PORT) \
	  --bind $(SERVE-HOST)

publish: build
	cd $(SITE) && \
	  git init && \
	  git add -A && \
	  git commit -m 'Deploy to production' && \
	  git push -f $(REPO) HEAD:gh-pages
	$(RM) -r $(SITE)

$(SITE):
	mkdir -p $@

$(SITE)/examples:
	mkdir -p $@

$(SITE)/examples/%: src/examples/% | $(SITE)/examples
	cp $< $@

$(SITE)/index.html: src/index.html | $(SITE)
	cp $< $@

$(SITE)/app.js: src/app.js | $(SITE)
	cp $< $@

$(SITE)/json.js: src/json.js | $(SITE)
	cp $< $@

$(SITE)/schema-worker.js: src/schema-worker.js | $(SITE)
	cp $< $@

$(SITE)/roundtrip-worker.js: src/roundtrip-worker.js | $(SITE)
	cp $< $@

$(SITE)/unified-diff.js: src/unified-diff.js | $(SITE)
	cp $< $@

$(SITE)/style.css: src/style.css | $(SITE)
	cp $< $@

$(SITE)/values.ysd.yaml: src/values.ysd.yaml | $(SITE)
	cp $< $@

$(WASM): ../bin/ysc $(GLOAT) | $(SITE)
	$(GLOAT-ENV) $(GLOAT) -qf -t js -o $@ $<

$(WASM-EXEC): $(GLOAT) | $(SITE)
	go_bin=$$($(GLOAT) --which=go); \
	  go_root=$$($$go_bin env GOROOT); \
	  cp $$go_root/lib/wasm/wasm_exec.js $@

clean::
	$(RM) -r $(SITE)
