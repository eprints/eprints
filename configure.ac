AC_INIT(eprints, m4_esyscmd([grep \$VERSION perl_lib/EPrints.pm | sed 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/' | tr -d '\n']))
AM_INIT_AUTOMAKE

DIST_PATH=`pwd`
INSTALL_USER=eprints
INSTALL_GROUP=eprints
DEBIAN_DATE=`LANG=C date -R`
DEBIAN_TYPE="UNRELEASED"

PERL_SEARCH_PATH="$PATH:/usr/local/bin:/opt/perl/bin:/opt/PERL/bin"
AC_ARG_WITH(perl,
    [  --with-perl=[PATH]        path of perl interpreter ],
    [
        AC_MSG_CHECKING([perl interpreter])
        PERL_PATH=$withval
        if test -x $PERL_PATH ; then
            AC_MSG_RESULT($PERL_PATH)
        else
            AC_MSG_ERROR(Perl interpreter specified does not appear to exist)
        fi
    ],
    [
        AC_PATH_PROG(PERL_PATH, perl, "NOTFOUND", $PERL_SEARCH_PATH)
        if test $PERL_PATH = NOTFOUND ; then
            AC_MSG_ERROR(Unable to find perl interpreter)
        fi
    ]
)

AC_MSG_CHECKING([whether the perl interpreter ($PERL_PATH ) runs])
if $PERL_PATH -e "" > /dev/null 2>&1 ; then
    AC_MSG_RESULT(yes)
else
    AC_MSG_RESULT(no)
    AC_MSG_ERROR(Perl interpreter does not appear to run)
fi

AC_MSG_CHECKING([whether the perl interpreter ($PERL_PATH ) works])
if $PERL_PATH -e " print(\"INSERT PERL TEST HERE\")" > /dev/null 2>&1 ; then
    AC_MSG_RESULT(yes)
else
    AC_MSG_RESULT(no)
    AC_MSG_ERROR(Perl interpreter does not appear to work)
fi

AC_ARG_WITH(user,
    [  --with-user=[USER]        install eprints to run as USER ],
    [
        INSTALL_USER=$withval
    ])

AC_ARG_WITH(group,
    [  --with-group=[GROUP]      install eprints to run as GROUP ],
    [
        INSTALL_GROUP=$withval
    ])

enableval="yes"

AC_MSG_CHECKING([whether to check the user $INSTALL_USER exists])
AC_ARG_ENABLE(user-check,
	[AS_HELP_STRING([--disable-user-check],[don't check user exists]) ])

case "$enableval" in
	yes)
		ignore_usercheck=false
		;;
	no)
		ignore_usercheck=true
		;;
	'')
		ignore_usercheck=true
		;;
	*)
		AC_MSG_ERROR([--disable-user-check takes yes or no])
esac
if $ignore_usercheck ; then
	AC_MSG_RESULT(no)
else
	AC_MSG_RESULT(yes)
	AC_MSG_CHECKING([whether the user $INSTALL_USER exists])
	if $PERL_PATH -e "getpwnam(\"$INSTALL_USER\")?exit 0:exit 1;" > /dev/null 2>&1 ; then
		AC_MSG_RESULT(yes)
	else
		AC_MSG_RESULT(no)	
		AC_MSG_ERROR(User $INSTALL_USER does not appear to exist)
	fi
fi

enableval="yes"

AC_MSG_CHECKING([whether to check the group $INSTALL_GROUP exists])
AC_ARG_ENABLE(group-check,
	[AS_HELP_STRING([--disable-group-check],[don't check group exists]) ])

case "$enableval" in
	yes)
		ignore_groupcheck=false
		;;
	no)
		ignore_groupcheck=true
		;;
	'')
		ignore_groupcheck=true
		;;
	*)
		AC_MSG_ERROR([--disable-group-check takes yes or no])
esac
if $ignore_groupcheck ; then
	AC_MSG_RESULT(no)
else
	AC_MSG_RESULT(yes)
	AC_MSG_CHECKING([whether the group $INSTALL_GROUP exists])
	if $PERL_PATH -e "getgrnam(\"$INSTALL_GROUP\")?exit 0:exit 1;" > /dev/null 2>&1 ; then
		AC_MSG_RESULT(yes)
	else
		AC_MSG_RESULT(no)	
		AC_MSG_ERROR(Group $INSTALL_GROUP does not appear to exist)
	fi
fi

APACHE="2"

SMTP_SERVER="smtp"
AC_ARG_WITH(smtp-server,
    [  --with-smtp-server=[HOSTNAME]  
                          SMTP server to use for outgoing email],
    [
        SMTP_SERVER=$withval
    ])
if test "$SMTP_SERVER" = "yes" ; then
	echo "Please actually specify a STMP server."
	exit 1;
fi

dnl This is the path that we search for tools

TOOL_PATH="$PATH:/usr/local/bin:/sbin:/usr/sbin:/usr/X11R6/bin:/usr/lib"
AC_ARG_WITH(toolpath,
    [  --with-toolpath=[PATH]    search path for tool programs ],
    [
        TOOL_PATH=$withval
    ])

AC_ARG_WITH(debian_unstable,
    [  --with-debian-unstable    unstable debian release],
    [
        DEBIAN_TYPE="unstable"
    ])
AC_ARG_WITH(debian_stable,
    [  --with-debian-stable      stable debian release],
    [
        DEBIAN_TYPE="stable"
    ])

# Check for any non-core Perl modules here
#CHECK_PERL_MOD(Digest::MD5)

AC_PREFIX_DEFAULT(/opt/eprints3)

PREFIX=$prefix
if test $PREFIX = "NONE" ; then
    PREFIX=/opt/eprints3
fi

PLATFORM="unix";

AC_SUBST(PERL_PATH)
AC_SUBST(DIST_PATH)
AC_SUBST(PREFIX)
AC_SUBST(INSTALL_USER)
AC_SUBST(INSTALL_GROUP)
AC_SUBST(SMTP_SERVER)
AC_SUBST(PLATFORM)
AC_SUBST(DEBIAN_DATE)
AC_SUBST(DEBIAN_TYPE)



AC_CONFIG_FILES([debian/rules], [chmod +x debian/rules])
AC_CONFIG_FILES([debian/postinst], [chmod +x debian/postinst])
AC_CONFIG_FILES([debian/postrm], [chmod +x debian/postrm])
AC_CONFIG_FILES([debian/preinst], [chmod +x debian/preinst])
AC_CONFIG_FILES([debian/prerm], [chmod +x debian/prerm])
AC_CONFIG_FILES([bin/epindexer], [chmod +x bin/epindexer])

AC_OUTPUT(Makefile perl_lib/EPrints/SystemSettings.pm install.pl eprints.spec debian/changelog)
