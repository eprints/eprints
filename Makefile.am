EXTRA_INST = AUTHORS VERSION
EXTRA_DIST = eprints.spec AUTHORS VERSION 

install-data-hook: doc
	@for f in $(EXTRA_INST); do \
		$(INSTALL_DATA) $$f $(PREFIX)/$$f; \
	done
	$(PERL_PATH) install.pl

dist-hook: doc
	DESTDIR=$(CURDIR)/$(distdir) $(PERL_PATH) install.pl

uninstall-hook:
	$(PERL_PATH) install.pl --uninstall

doc: ChangeLog INSTALL README VERSION

ChangeLog:
	$(PERL_PATH) tools/gitlog-to-changelog > ChangeLog

INSTALL:
	pod2text README.pod > INSTALL

README:
	pod2text README.pod > README

VERSION:
	echo $(VERSION) > VERSION

clean-local:
	-rm -f configure Makefile.in ChangeLog install-sh missing INSTALL VERSION
	-rm -f aclocal.m4 eprints.spec Makefile README install.pl
	-rm -f config.status config.log bin/epindexer
	-rm -rf autom4te.cache

# won't back-port the master test features onto 3.3
test:
	EPRINTS_NO_CHECK_USER=1 $(PERL_PATH) bin/epadmin test
