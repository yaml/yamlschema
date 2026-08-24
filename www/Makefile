R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk

GLOAT-VERSION := 0.1.78
NODE-VERSION := 26.7.0
PYTHON-VENV := $(ROOT)/venv

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
include $M/typos.mk
include $M/clean.mk

SHELL-DEPS += $(PYTHON-VENV)

include $M/shell.mk

export UV_LINK_MODE := copy
export UV_CACHE_DIR := $(CURDIR)/.cache/uv
export NO_MKDOCS_2_WARNING := 1

REPO ?= git@github.com:yaml/yamlschema
SERVE-HOST ?= localhost
SERVE-PORT ?= 8000

EDITOR-ASSETS := docs/assets/editor
WASM := $(EDITOR-ASSETS)/ysd.wasm
WASM-EXEC := $(EDITOR-ASSETS)/wasm_exec.js
YAMLSCRIPT-DIR := ../../yamlscript
LOCAL-YS := $(wildcard $(YAMLSCRIPT-DIR)/ys/bin/ys)
GLOAT-ENV := $(if $(LOCAL-YS),GLOAT_YS=$(abspath $(LOCAL-YS)))
DEPS := $(PYTHON-VENV) $(WASM) $(WASM-EXEC)

MAKES-CLEAN := site $(WASM) $(WASM-EXEC)
MAKES-REALCLEAN := $(PYTHON-VENV)

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

$(WASM): ../bin/ysd $(GLOAT)
	$(GLOAT-ENV) $(GLOAT) -qf -t js -o $@ $<

$(WASM-EXEC): $(GLOAT)
	go_bin=$$($(GLOAT) --which=go); \
	  go_root=$$($$go_bin env GOROOT); \
	  cp $$go_root/lib/wasm/wasm_exec.js $@

FORCE:
