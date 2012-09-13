install-data-hook:
	$(PERL_PATH) install.pl

dist-hook: ChangeLog INSTALL VERSION
	DESTDIR=$(CURDIR)/$(distdir) $(PERL_PATH) install.pl

uninstall-hook:
	$(PERL_PATH) install.pl --uninstall

ChangeLog:
	$(PERL_PATH) tools/gitlog-to-changelog > ChangeLog

INSTALL:
	pod2txt README > INSTALL

VERSION:
	echo $(VERSION) > VERSION

clean-local:
	-rm -f configure Makefile.in ChangeLog install-sh missing INSTALL VERSION
	-rm -rf autom4te.cache
