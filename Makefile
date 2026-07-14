R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk
include $M/perl.mk
include $M/yamlscript.mk
include $M/clean.mk
include $M/shell.mk


test: $(YS) $(PERL)
	prove$(if $v, -v) test/*.t

json-schema-suite:
	util/ysc-suite-roundtrip --fetch-only

suite-roundtrip:
	util/ysc-suite-roundtrip draft4
