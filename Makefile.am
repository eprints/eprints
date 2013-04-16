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
	pod2text README.POD > INSTALL

README:
	pod2text README.POD > README

VERSION:
	echo $(VERSION) > VERSION

clean-local:
	-rm -f configure Makefile.in ChangeLog install-sh missing INSTALL VERSION
	-rm -f aclocal.m4 eprints.spec Makefile README install.pl
	-rm -f config.status config.log bin/epindexer
	-rm -rf autom4te.cache

test:
	$(PERL_PATH) bin/epadmin create_test --force --quiet
	$(PERL_PATH) bin/epadmin create_user test _
	$(PERL_PATH) testdata/bin/import_test_data test
	$(PERL_PATH) bin/indexer --once --notdaemon start
	$(PERL_PATH) bin/epadmin unit_tests
	$(PERL_PATH) bin/epadmin delete test --force
