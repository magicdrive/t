PREFIX=${HOME}/local
CURRENTDIR=$(shell pwd -L | perl -p -e 's/ /\\ /g')

all:
	@echo "make [intall|uninstall]"

man:
	[ -e $(shell which md2man-roff) ] && md2man-roff $(CURRENTDIR)/README.md > $(CURRENTDIR)/t.1

install:
	mkdir -p $(PREFIX)/bin/ $(PREFIX)/share/man/man1/
	cp -af $(CURRENTDIR)/t $(PREFIX)/bin/
	cp -af $(CURRENTDIR)/t.1 $(PREFIX)/share/man/man1/

uninstall:
	rm -f $(PREFIX)/bin/t
	rm -f  $(PREFIX)/share/man/man1/t.1

