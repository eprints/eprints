# -*- perl -*-
#
#   DBI::ProxyServer - a proxy server for DBI drivers
#
#   Copyright (c) 1997  Jochen Wiedmann
#
#   The DBD::Proxy module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself. In particular permission
#   is granted to Tim Bunce for distributing this as a part of the DBI.
#
#
#   Author: Jochen Wiedmann
#           Am Eisteich 9
#           72555 Metzingen
#           Germany
#
#           Email: joe@ispsoft.de
#           Phone: +49 7123 14881
#
#

require 5.004;
use strict;

use RPC::PlServer 0.2001;
require DBI;
require Config;


package DBI::ProxyServer;


my $haveFileSpec = eval { require File::Spec };
my $tmpDir = $haveFileSpec ? File::Spec->tmpdir() :
    ($ENV{'TMP'} || $ENV{'TEMP'} || '/tmp');
my $defaultPidFile = $haveFileSpec ?
    File::Spec->catdir($tmpDir, "dbiproxy.pid") : "/tmp/dbiproxy.pid";


############################################################################
#
#   Constants
#
############################################################################

use vars qw($VERSION @ISA);

$VERSION = "0.2004";
@ISA = qw(RPC::PlServer DBI);


# Most of the options below are set to default values, we note them here
# just for the sake of documentation.
my %DEFAULT_SERVER_OPTIONS;
{
    my $o = \%DEFAULT_SERVER_OPTIONS;
    $o->{'chroot'}     = undef,		# To be used in the initfile,
    					# after loading the required
    					# DBI drivers.
    $o->{'clients'} =
	[ { 'mask' => '.*',
	    'accept' => 1,
	    'cipher' => undef
	    }
	  ];
    $o->{'configfile'} = '/etc/dbiproxy.conf' if -f '/etc/dbiproxy.conf';
    $o->{'debug'}      = 0;
    $o->{'facility'}   = 'daemon';
    $o->{'group'}      = undef;
    $o->{'localaddr'}  = undef;		# Bind to any local IP number
    $o->{'localport'}  = undef;         # Must set port number on the
					# command line.
    $o->{'logfile'}    = undef;         # Use syslog or EventLog.
    $o->{'methods'}    = {
	'DBI::ProxyServer' => {
	    'NewHandle' => 1,
	    'CallMethod' => 1,
	    'DestroyHandle' => 1
	    },
	'DBI::ProxyServer::db' => {
	    'prepare' => 1,
	    'commit' => 1,
	    'rollback' => 1,
	    'STORE' => 1,
	    'FETCH' => 1,
	    'func' => 1,
	    'quote' => 1,
	    'type_info_all' => 1,
            'table_info' => 1
	    },
	'DBI::ProxyServer::st' => {
	    'execute' => 1,
	    'STORE' => 1,
	    'FETCH' => 1,
	    'func' => 1,
	    'fetch' => 1,
	    'finish' => 1
	    }
    };
    if ($Config::Config{'usethreads'} eq 'define') {
	$o->{'mode'} = 'threads';
    } elsif ($Config::Config{'d_fork'} eq 'define') {
	$o->{'mode'} = 'fork';
    } else {
	$o->{'mode'} = 'single';
    }
    $o->{'pidfile'}    = $defaultPidFile;
    $o->{'user'}       = undef;
};


############################################################################
#
#   Name:    Version
#
#   Purpose: Return version string
#
#   Inputs:  $class - This class
#
#   Result:  Version string; suitable for printing by "--version"
#
############################################################################

sub Version {
    my $version = $DBI::ProxyServer::VERSION;
    "DBI::ProxyServer $version, Copyright (C) 1998, Jochen Wiedmann";
}


############################################################################
#
#   Name:    AcceptApplication
#
#   Purpose: Verify DBI DSN
#
#   Inputs:  $self - This instance
#            $dsn - DBI dsn
#
#   Returns: TRUE for a valid DSN, FALSE otherwise
#
############################################################################

sub AcceptApplication {
    my $self = shift; my $dsn = shift;
    $dsn =~ /^dbi:\w+:/i;
}


############################################################################
#
#   Name:    AcceptVersion
#
#   Purpose: Verify requested DBI version
#
#   Inputs:  $self - Instance
#            $version - DBI version being requested
#
#   Returns: TRUE for ok, FALSE otherwise
#
############################################################################

sub AcceptVersion {
    my $self = shift; my $version = shift;
    $DBI::VERSION >= $version;
}


############################################################################
#
#   Name:    AcceptUser
#
#   Purpose: Verify user and password by connecting to the client and
#            creating a database connection
#
#   Inputs:  $self - Instance
#            $user - User name
#            $password - Password
#
############################################################################

sub AcceptUser {
    my $self = shift; my $user = shift; my $password = shift;
    return 0 if (!$self->SUPER::AcceptUser($user, $password));
    my $dsn = $self->{'application'};
    $self->Debug("Connecting to $dsn as $user");
    local $ENV{DBI_AUTOPROXY} = ''; # :-)
    $self->{'dbh'} = eval {
	DBI::ProxyServer->connect($dsn, $user, $password,
				  { 'PrintError' => 0, 'Warn' => 0,
				    RaiseError => 1 })
    };
    if ($@) {
	$self->Error("Error while connecting to $dsn as $user: $@");
	return 0;
    }
    [1, $self->StoreHandle($self->{'dbh'}) ];
}


sub CallMethod {
    my $server = shift;
    my $dbh = $server->{'dbh'};
    # We could store the private_server attribute permanently in
    # $dbh. However, we'd have a reference loop in that case and
    # I would be concerned about garbage collection. :-(
    $dbh->{'private_server'} = $server;
    $server->Debug("CallMethod: => " . join(",", @_));
    my @result = eval { $server->SUPER::CallMethod(@_) };
    undef $dbh->{'private_server'};
    if (my $msg = $@) {
	$server->Error($msg);
	die $msg;
    } else {
	$server->Debug("CallMethod: <= " . join(",", @result));
    }
    @result;
}


sub main {
    my $server = DBI::ProxyServer->new(\%DEFAULT_SERVER_OPTIONS, \@_);
    $server->Bind();
}


############################################################################
#
#   The DBI part of the proxyserver is implemented as a DBI subclass.
#   Thus we can reuse some of the DBI methods and overwrite only
#   those that need additional handling.
#
############################################################################

DBI::ProxyServer->init_rootclass();

package DBI::ProxyServer::dr;

@DBI::ProxyServer::dr::ISA = qw(DBI::dr);


package DBI::ProxyServer::db;

@DBI::ProxyServer::db::ISA = qw(DBI::db);

sub prepare {
    my($dbh, $statement, $attr, $params) = @_;
    my $server = $dbh->{'private_server'};
    if (my $client = $server->{'client'}) {
	if ($client->{'sql'}) {
	    if ($statement =~ /^\s*(\S+)/) {
		my $st = $1;
		if (!($statement = $client->{'sql'}->{$st})) {
		    die "Unknown SQL query: $st";
		}
	    } else {
		die "Cannot parse restricted SQL statement: $statement";
	    }
	}
    }

    # The difference between the usual prepare and ours is that we implement
    # a combined prepare/execute. The DBD::Proxy driver doesn't call us for
    # prepare. Only if an execute happens, then we are called with method
    # "prepare". Further execute's are called as "execute".
    my $sth = $dbh->SUPER::prepare($statement, $attr);
    my @result = $sth->execute($params);
    my $handle = $server->StoreHandle($sth);
    my ($NAME, $TYPE);
    my $NUM_OF_FIELDS = $sth->{NUM_OF_FIELDS};
    if ($NUM_OF_FIELDS) {	# is a SELECT
	$NAME = $sth->{NAME};
	$TYPE = $sth->{TYPE};
    }
    ($handle, $NUM_OF_FIELDS, $sth->{'NUM_OF_PARAMS'},
     $NAME, $TYPE, @result);
}

sub table_info {
    my $dbh = shift;
    my $sth = $dbh->SUPER::table_info();
    my $numFields = $sth->{'NUM_OF_FIELDS'};
    my $names = $sth->{'NAME'};
    my $types = $sth->{'TYPE'};

    # We wouldn't need to send all the rows at this point, instead we could
    # make use of $rsth->fetch() on the client as usual.
    # The problem is that some drivers (namely DBD::ExampleP, DBD::mysql and
    # DBD::mSQL) are returning foreign sth's here, thus an instance of
    # DBI::st and not DBI::ProxyServer::st. We could fix this by permitting
    # the client to execute method DBI::st, but I don't like this.
    my @rows;
    while (my $row = $sth->fetchrow_arrayref()) {
	push(@rows, [@$row]);
    }
    ($numFields, $names, $types, @rows);
}


package DBI::ProxyServer::st;

@DBI::ProxyServer::st::ISA = qw(DBI::st);

sub execute {
    my $sth = shift; my $params = shift;
    my @outParams;

    if ($params) {
	for (my $i = 0;  $i < @$params;) {
	    my $param = $params->[$i++];
	    if (!ref($param)) {
		$sth->bind_param($i, $param);
	    } else {
		# value, type => bind_param,
		# value, type, maxlen => bind_param_inout
		if (@$param <= 2) {
		    $sth->bind_param($i, @$param);
		} else {
		    $sth->bind_param_inout($i, @$param);
		    my $ref = shift @$param;
		    push(@outParams, $ref);
		}
	    }
	}
    }

    my $rows = $sth->SUPER::execute();
    ($rows, @outParams);
}

sub fetch {
    my $sth = shift; my $numRows = shift || 1;
    my($ref, @rows);
    while ($numRows--  &&  ($ref = $sth->fetchrow_arrayref())) {
	push(@rows, [@$ref]);
    }
    @rows;
}


1;


__END__

=head1 NAME

DBI::ProxyServer - a server for the DBD::Proxy driver


=head1 SYNOPSIS

    use DBI::ProxyServer;
    DBI::ProxyServer::main(@ARGV);


=head1 DESCRIPTION

DBI::Proxy Server is a module for implementing a proxy for the DBI proxy
driver, DBD::Proxy. It allows access to databases over the network if the
DBMS does not offer networked operations. But the proxy server might be
usefull for you, even if you have a DBMS with integrated network
functionality: It can be used as a DBI proxy in a firewalled environment.

DBI::ProxyServer runs as a daemon on the machine with the DBMS or on the
firewall. The client connects to the agent using the DBI driver DBD::Proxy,
thus in the exactly same way than using DBD::mysql, DBD::mSQL or any other
DBI driver.

The agent is implemented as a RPC::PlServer application. Thus you have
access to all the possibilities of this module, in particular encryption
and a similar configuration file. DBI::ProxyServer adds the possibility of
query restrictions: You can define a set of queries that a client may
execute and restrict access to those. (Requires a DBI driver that supports
parameter binding.) See L</CONFIGURATION FILE>.


=head1 OPTIONS

When calling the DBI::ProxyServer::main() function, you supply an
array of options. (@ARGV, the array of command line options is used,
if you don't.) These options are parsed by the Getopt::Long module.
The ProxyServer inherits all of RPC::PlServer's and hence Net::Daemon's
options and option handling, in particular the ability to read
options from either the command line or a config file. See
L<RPC::PlServer(3)>. See L<Net::Daemon(3)>. Available options include

=over 4

=item I<chroot> (B<--chroot=dir>)

(UNIX only)  After doing a bind(), change root directory to the given
directory by doing a chroot(). This is usefull for security, but it
restricts the environment a lot. For example, you need to load DBI
drivers in the config file or you have to create hard links to Unix
sockets, if your drivers are using them. For example, with MySQL, a
config file might contain the following lines:

    my $rootdir = '/var/dbiproxy';
    my $unixsockdir = '/tmp';
    my $unixsockfile = 'mysql.sock';
    foreach $dir ($rootdir, "$rootdir$unixsockdir") {
	mkdir 0755, $dir;
    }
    link("$unixsockdir/$unixsockfile",
	 "$rootdir$unixsockdir/$unixsockfile");
    require DBD::mysql;

    {
	'chroot' => $rootdir,
	...
    }

If you don't know chroot(), think of an FTP server where you can see a
certain directory tree only after logging in. See also the --group and
--user options.

=item I<clients>

An array ref with a list of clients. Clients are hash refs, the attributes
I<accept> (0 for denying access and 1 for permitting) and I<mask>, a Perl
regular expression for the clients IP number or its host name. See
L<"Access control"> below.

=item I<configfile> (B<--configfile=file>)

Config files are assumed to return a single hash ref that overrides the
arguments of the new method. However, command line arguments in turn take
precedence over the config file. See the L<"CONFIGURATION FILE"> section
below for details on the config file.

=item I<debug> (B<--debug>)

Turn debugging mode on. Mainly this asserts that logging messages of
level "debug" are created.

=item I<facility> (B<--facility=mode>)

(UNIX only) Facility to use for L<Sys::Syslog (3)>. The default is
B<daemon>.

=item I<group> (B<--group=gid>)

After doing a bind(), change the real and effective GID to the given.
This is usefull, if you want your server to bind to a privileged port
(<1024), but don't want the server to execute as root. See also
the --user option.

GID's can be passed as group names or numeric values.

=item I<localaddr> (B<--localaddr=ip>)

By default a daemon is listening to any IP number that a machine
has. This attribute allows to restrict the server to the given
IP number.

=item I<localport> (B<--localport=port>)

This attribute sets the port on which the daemon is listening. It
must be given somehow, as there's no default.

=item I<logfile> (B<--logfile=file>)

Be default logging messages will be written to the syslog (Unix) or
to the event log (Windows NT). On other operating systems you need to
specify a log file. The special value "STDERR" forces logging to
stderr. See L<Net::Daemon::Log(3)> for details.

=item I<mode> (B<--mode=modename>)

The server can run in three different modes, depending on the environment.

If you are running Perl 5.005 and did compile it for threads, then the
server will create a new thread for each connection. The thread will
execute the server's Run() method and then terminate. This mode is the
default, you can force it with "--mode=threads".

If threads are not available, but you have a working fork(), then the
server will behave similar by creating a new process for each connection.
This mode will be used automatically in the absence of threads or if
you use the "--mode=fork" option.

Finally there's a single-connection mode: If the server has accepted a
connection, he will enter the Run() method. No other connections are
accepted until the Run() method returns (if the client disconnects).
This operation mode is usefull if you have neither threads nor fork(),
for example on the Macintosh. For debugging purposes you can force this
mode with "--mode=single".

=item I<pidfile> (B<--pidfile=file>)

(UNIX only) If this option is present, a PID file will be created at the
given location.

=item I<user> (B<--user=uid>)

After doing a bind(), change the real and effective UID to the given.
This is usefull, if you want your server to bind to a privileged port
(<1024), but don't want the server to execute as root. See also
the --group and the --chroot options.

UID's can be passed as group names or numeric values.

=item I<version> (B<--version>)

Supresses startup of the server; instead the version string will
be printed and the program exits immediately.

=back


=head1 CONFIGURATION FILE

The configuration file is just that of I<RPC::PlServer> or I<Net::Daemon>
with some additional attributes in the client list.

The config file is a Perl script. At the top of the file you may include
arbitraty Perl source, for example load drivers at the start (usefull
to enhance performance), prepare a chroot environment and so on.

The important thing is that you finally return a hash ref of option
name/value pairs. The possible options are listed above.

All possibilities of Net::Daemon and RPC::PlServer apply, in particular

=over 4

=item Host and/or User dependent access control

=item Host and/or User dependent encryption

=item Changing UID and/or GID after binding to the port

=item Running in a chroot() environment

=back

Additionally the server offers you query restrictions. Suggest the
following client list:

    'clients' => [
	{ 'mask' => '^admin\.company\.com$',
          'accept' => 1,
          'users' => [ 'root', 'wwwrun' ],
        },
        {
	  'mask' => '^admin\.company\.com$',
          'accept' => 1,
          'users' => [ 'root', 'wwwrun' ],
          'sql' => {
               'select' => 'SELECT * FROM foo',
               'insert' => 'INSERT INTO foo VALUES (?, ?, ?)'
               }
        }

then only the users root and wwwrun may connect from admin.company.com,
executing arbitrary queries, but only wwwrun may connect from other
hosts and is restricted to

    $sth->prepare("select");

or

    $sth->prepare("insert");

which in fact are "SELECT * FROM foo" or "INSERT INTO foo VALUES (?, ?, ?)".




=head1 AUTHOR

    Copyright (c) 1997    Jochen Wiedmann
                          Am Eisteich 9
                          72555 Metzingen
                          Germany

                          Email: joe@ispsoft.de
                          Phone: +49 7123 14881

The DBI::ProxyServer module is free software; you can redistribute it
and/or modify it under the same terms as Perl itself. In particular
permission is granted to Tim Bunce for distributing this as a part of
the DBI.


=head1 SEE ALSO

L<dbiproxy(1)>, L<DBD::Proxy(3)>, L<DBI(3)>, L<RPC::PlServer(3)>,
L<RPC::PlClient(3)>, L<Net::Daemon(3)>, L<Net::Daemon::Log(3)>,
L<Sys::Syslog(3)>, L<Win32::EventLog(3)>, L<syslog(2)>
