R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk

PYTHON-VENV := $(ROOT)/venv

LOCAL-GLOAT-DIR := $(if \
  $(wildcard ../repos/gloat/bin/gloat),../repos/gloat)

ifneq (,$(GLOAT_ROOT))
GLOAT-DIR ?= $(GLOAT_ROOT)
else ifneq (,$(LOCAL-GLOAT-DIR))
GLOAT-DIR ?= $(abspath $(LOCAL-GLOAT-DIR))
endif

include $M/gloat.mk
include $M/node.mk
include $M/python.mk
include $M/typos.mk
include $M/clean.mk

SHELL-DEPS += $(PYTHON-VENV)

include $M/shell.mk

export UV_LINK_MODE := copy
export UV_CACHE_DIR := $(CURDIR)/.cache/uv
export NPM_CONFIG_CACHE := $(LOCAL-CACHE)/npm
export NO_MKDOCS_2_WARNING := 1

REPO ?= git@github.com:yaml/yamlschema
SERVE-HOST ?= localhost
SERVE-PORT ?= 8000

EDITOR-ASSETS := docs/assets/editor
EDITOR-SOURCE := src/editor
EDITOR-BUNDLE := $(EDITOR-ASSETS)/app.js
EDITOR-SOURCES := $(wildcard $(EDITOR-SOURCE)/*.js)
WASM := $(EDITOR-ASSETS)/ysd.wasm
WASM-EXEC := $(EDITOR-ASSETS)/wasm_exec.js
NODE-MODULES := node_modules
DEPS := $(PYTHON-VENV) $(EDITOR-BUNDLE) $(WASM) $(WASM-EXEC)

MAKES-CLEAN := site $(EDITOR-BUNDLE) $(WASM) $(WASM-EXEC)
MAKES-REALCLEAN := $(PYTHON-VENV) node_modules

default:: site

site: $(DEPS) FORCE
	mkdocs build --strict -d $@

build: site

test: site $(NODE)
	$(NODE) test/smoke.mjs

serve: $(DEPS)
	@printf '\nYAMLSchema: http://$(SERVE-HOST):$(SERVE-PORT)/\n\n'
	mkdocs serve --livereload -a $(SERVE-HOST):$(SERVE-PORT)

lint: $(TYPOS)
	typos docs mkdocs.yaml

publish: site
	cd $< && \
	  git init && \
	  git add -A && \
	  git commit -m 'Deploy YAMLSchema website' && \
	  git push -f $(REPO) HEAD:gh-pages
	$(RM) -r $<

$(EDITOR-BUNDLE): $(EDITOR-SOURCES) rollup.config.mjs $(NODE-MODULES)
	node_modules/.bin/rollup --config

$(NODE-MODULES): package.json package-lock.json $(NODE)
	npm ci

$(WASM): \
  ../lib/ysd/core.ys ../lib/ysd/cli.ys ../util/compose-ysd $(GLOAT)
	$(MAKE) -C .. .cache/ysd-cli.ys
	$(GLOAT) -qf -t js -o $@ ../.cache/ysd-cli.ys

$(WASM-EXEC): $(GLOAT)
	go_bin=$$($(GLOAT) --which=go); \
	  go_root=$$($$go_bin env GOROOT); \
	  cp $$go_root/lib/wasm/wasm_exec.js $@

FORCE:
