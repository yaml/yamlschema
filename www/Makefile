R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk

GLOAT-VERSION := 0.1.78
NODE-VERSION := 26.7.0

include $M/gloat.mk
include $M/node.mk
include $M/clean.mk
include $M/shell.mk

SITE := site
WASM := $(SITE)/ysc.wasm
WASM-EXEC := $(SITE)/wasm_exec.js
YAMLSCRIPT-DIR := ../../yamlscript
LOCAL-YS := $(wildcard $(YAMLSCRIPT-DIR)/ys/bin/ys)
GLOAT-ENV := $(if $(LOCAL-YS),GLOAT_YS=$(abspath $(LOCAL-YS)))

build: $(SITE)/index.html $(SITE)/app.js $(SITE)/style.css \
  $(WASM-EXEC) $(WASM)

test: build $(NODE)
	cd $(SITE) && $(NODE) ../test/smoke.mjs

$(SITE):
	mkdir -p $@

$(SITE)/index.html: src/index.html | $(SITE)
	cp $< $@

$(SITE)/app.js: src/app.js | $(SITE)
	cp $< $@

$(SITE)/style.css: src/style.css | $(SITE)
	cp $< $@

$(WASM): ../bin/ysc $(GLOAT) | $(SITE)
	$(GLOAT-ENV) $(GLOAT) -qf -t js -o $@ $<

$(WASM-EXEC): $(GLOAT) | $(SITE)
	go_bin=$$($(GLOAT) --which=go); \
	  go_root=$$($$go_bin env GOROOT); \
	  cp $$go_root/lib/wasm/wasm_exec.js $@

clean::
	$(RM) -r $(SITE)
