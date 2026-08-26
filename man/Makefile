R := https://github.com/makeplus/makes
M := ../.cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

MAKES_LOCAL_DIR ?= $(abspath ../.cache/local)

include $M/init.mk
include $M/md2man.mk
include $M/perl.mk

MAN-ROOT ?= $(CURDIR)
MAN-PAGES := \
  $(MAN-ROOT)/man1/ysd.1 \
  $(MAN-ROOT)/man5/yamlschema.5 \
  $(MAN-ROOT)/man5/yamlschema-design.5 \
  $(MAN-ROOT)/man5/yamlschema-json-schema.5

default:: man

man: $(MAN-PAGES)

test: $(MD2MAN) $(PERL)
	$(RM) -r '$(abspath ../.cache/man-test)'
	$(MAKE) --no-print-directory \
	  MAN-ROOT='$(abspath ../.cache/man-test)' man
	diff -ru '$(CURDIR)/man1' '$(abspath ../.cache/man-test/man1)'
	diff -ru '$(CURDIR)/man5' '$(abspath ../.cache/man-test/man5)'

$(MAN-ROOT)/man1/ysd.1: ../www/docs/cli.md Makefile $(MD2MAN) $(PERL)
	@mkdir -p '$(@D)'
	$(PERL) -0pe 's/\A---\n.*?\n---\n+//s' < '$<' | \
	  $(MD2MAN) | \
	  $(PERL) -pe \
	    's/[ \t]+$$//; \
	     s/^\.TH (\S+) - .*/.TH $$1 1 "" YAMLSchema YAMLSchema/' > '$@'

$(MAN-ROOT)/man5/yamlschema.5: \
    ../www/docs/reference/dsl.md Makefile $(MD2MAN) $(PERL)
	@mkdir -p '$(@D)'
	$(PERL) -0pe 's/\A---\n.*?\n---\n+//s' < '$<' | \
	  $(MD2MAN) | \
	  $(PERL) -pe \
	    's/[ \t]+$$//; \
	     s/^\.TH (\S+) - .*/.TH $$1 5 "" YAMLSchema YAMLSchema/' > '$@'

$(MAN-ROOT)/man5/yamlschema-design.5: \
    ../www/docs/reference/design.md Makefile $(MD2MAN) $(PERL)
	@mkdir -p '$(@D)'
	$(PERL) -0pe 's/\A---\n.*?\n---\n+//s' < '$<' | \
	  $(MD2MAN) | \
	  $(PERL) -pe \
	    's/[ \t]+$$//; \
	     s/^\.TH (\S+) - .*/.TH $$1 5 "" YAMLSchema YAMLSchema/' > '$@'

$(MAN-ROOT)/man5/yamlschema-json-schema.5: \
    ../www/docs/reference/json-schema.md Makefile $(MD2MAN) $(PERL)
	@mkdir -p '$(@D)'
	$(PERL) -0pe 's/\A---\n.*?\n---\n+//s' < '$<' | \
	  $(MD2MAN) | \
	  $(PERL) -pe \
	    's/[ \t]+$$//; \
	     s/^\.TH (\S+) - .*/.TH $$1 5 "" YAMLSchema YAMLSchema/' > '$@'
