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

test:
	$(PERL_PATH) bin/epadmin create_test --force --quiet
	$(PERL_PATH) bin/epadmin create_user test _
	$(PERL_PATH) testdata/bin/import_test_data test
	$(PERL_PATH) bin/indexer --once --notdaemon start
	$(PERL_PATH) bin/epadmin unit_tests
	$(PERL_PATH) bin/epadmin delete test --force
