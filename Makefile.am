EXTRA_INST = AUTHORS VERSION
EXTRA_DIST = eprints.spec AUTHORS VERSION README.pod debian

install-data-hook:
	mkdir -p $(DESTDIR)$(PREFIX)
	@for f in $(EXTRA_INST); do \
		$(INSTALL_DATA) $$f $(DESTDIR)$(PREFIX)/$$f; \
	done
	DESTDIR=$(DESTDIR) $(PERL_PATH) install.pl

dist-hook:
	DESTDIR=$(CURDIR)/$(distdir) $(PERL_PATH) install.pl --dist

uninstall-hook:
	$(PERL_PATH) install.pl --uninstall

all: ChangeLog INSTALL README VERSION

ChangeLog:
	$(PERL_PATH) tools/gitlog-to-changelog > ChangeLog

INSTALL:
	pod2text README.pod > INSTALL

README:
	pod2text README.pod > README

VERSION:
	echo $(VERSION) > VERSION

clean-local:
	-rm -f ChangeLog INSTALL README VERSION

distclean-local:
	-rm -f eprints.spec perl_lib/EPrints/SystemSettings.pm bin/epindexer
	-rm -f debian/changelog debian/ debian/postinst debian/postrm debian/preinst debian/prerm

realclean: distclean
	-rm -f configure Makefile.in aclocal.m4 install-sh missing
	-rm -rf autom4te.cache

# won't back-port the master test features onto 3.3
test:
	EPRINTS_NO_CHECK_USER=1 $(PERL_PATH) bin/epadmin test
