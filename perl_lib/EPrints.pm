######################################################################
#
# EPrints
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints> - Institutional Repository software

=head1 SYNOPSIS

	use EPrints qw();

	my $session = EPrints::Session->new( 1, "demoprints" );

	...

	$session->terminate;

=head1 DESCRIPTION

See http://www.eprints.org/.

=head2 Available Symbols

You can pass options to the EPrints package that effect the EPrints initialisation e.g.

	use EPrints qw( no_check_user );

=over 4

=item no_check_user

Do not check the current user/group is the same as the user/group in Systemsettings.

=back

=head2 Debugging Slow Processes

This module installs a signal handler that will print a stack trace if given a USR2 signal (if your system supports this signal). To print a stack trace to the error log execute:

 $ kill -USR2 PID

Where PID is the id number of the stalled process.

A shell script will print the stack trace to the console.

=head1 METHODS

=over 4

=cut

package EPrints;

use EPrints::SystemSettings;
use EPrints::Config;

use Data::Dumper;
use Scalar::Util;

BEGIN {
	use Carp qw(cluck);

	# load the configuration - required by EPrints::Platform et al
	EPrints::Config::init();

	umask( 0002 );

	if( $ENV{MOD_PERL} )
	{
		eval '
use Apache::DBI; # must be first! 	 	 
#$Apache::DBI::DEBUG = 3;
use EPrints::Apache::AnApache;
use EPrints::Apache::LogHandler;
use EPrints::Apache::Login;
use EPrints::Apache::Auth;
use EPrints::Apache::Rewrite;
use EPrints::Apache::VLit;
use EPrints::Apache::Template;
use EPrints::Apache::Storage;
use EPrints::Apache::REST;
1;';
		if( $@ ) { abort( $@ ); }
	}

	# abort($err) Defined here so modules can abort even at startup
######################################################################
=pod

=item EPrints->abort( $errmsg )

Print an error message and exit. If running under mod_perl then
print the error as a webpage and exit.

This subroutine is loaded before other modules so that it may be
used to report errors when initialising modules.

=cut
######################################################################

	sub abort
	{
		my( $errmsg ) = pop @_; # last parameter

		my $r;
		if( $ENV{MOD_PERL} && $EPrints::SystemSettings::loaded)
		{
			$r = EPrints::Apache::AnApache::get_request();
		}
		if( defined $r )
		{
			# If we are running under MOD_PERL
			# AND this is actually a request, not startup,
			# then we should print an explanation to the
			# user in addition to logging to STDERR.
			my $htmlerrmsg = $errmsg;
			$htmlerrmsg=~s/&/&amp;/g;
			$htmlerrmsg=~s/>/&gt;/g;
			$htmlerrmsg=~s/</&lt;/g;
			$htmlerrmsg=~s/\n/<br \/>/g;
			$r->content_type( 'text/html' );
			EPrints::Apache::AnApache::send_status_line( $r, 500, "EPrints Internal Error" );

			EPrints::Apache::AnApache::send_http_header( $r );
			print <<END;
<html>
  <head>
    <title>EPrints System Error</title>
  </head>
  <body>
    <h1>EPrints System Error</h1>
    <p><tt>$htmlerrmsg</tt></p>
  </body>
</html>
END
		}

		
		print STDERR <<END;
	
------------------------------------------------------------------
---------------- EPrints System Error ----------------------------
------------------------------------------------------------------
$errmsg
------------------------------------------------------------------
END
		$@="";
		cluck( "EPrints System Error inducing stack dump\n" );
		if( $EPrints::die_on_abort ) { die $errmsg; }
		exit( 1 );
	}

	sub deprecated
	{
		my @c = caller(1);
		print STDERR "Called deprecated function $c[3] from $c[1] line $c[2]\n";
	}

	sub try
	{
		my( $code ) = @_;

		my $r = eval { &$code };

		if( $@ ) { EPrints::abort( $@ ); }

		return $r;
	}
}

use EPrints::BackCompatibility;
use EPrints::XML;
use EPrints::XHTML;
use EPrints::Utils;
use EPrints::Time;

use EPrints::Box;
use EPrints::Database;
use EPrints::Storage;
use EPrints::DataObj;
use EPrints::DataObj::SubObject;
use EPrints::DataObj::Access;
use EPrints::DataObj::Cachemap;
use EPrints::DataObj::Document;
use EPrints::DataObj::EPrint;
use EPrints::DataObj::File;
use EPrints::DataObj::History;
use EPrints::DataObj::Import;
use EPrints::DataObj::Import::XML;
use EPrints::DataObj::EventQueue;
use EPrints::DataObj::LoginTicket;
use EPrints::DataObj::Message;
use EPrints::DataObj::MetaField;
use EPrints::DataObj::Request;
use EPrints::DataObj::Subject;
use EPrints::DataObj::SavedSearch;
use EPrints::DataObj::UploadProgress;
use EPrints::DataObj::User;
use EPrints::DataSet;
use EPrints::Email;
use EPrints::Extras;
use EPrints::Index;
use EPrints::Index::Daemon;
use EPrints::Language;
use EPrints::Latex;
use EPrints::List;
use EPrints::MetaField;
use EPrints::OpenArchives;
use EPrints::Page;
use EPrints::Page::Text;
use EPrints::Page::DOM;
use EPrints::Paginate;
use EPrints::Paginate::Columns;
use EPrints::Platform;
use EPrints::Plugin;
use EPrints::PluginFactory;
use EPrints::Probity;
use EPrints::Repository;
use EPrints::RepositoryConfig;
use EPrints::Search;
use EPrints::Search::Field;
use EPrints::Search::Condition;
use EPrints::CLIProcessor;
use EPrints::ScreenProcessor;
use EPrints::Script;
use EPrints::Script::Compiler;
use EPrints::Script::Compiled;
use EPrints::URL;
use EPrints::Paracite;
use EPrints::Update::Static;
use EPrints::Update::Views;
use EPrints::Update::Abstract;
use EPrints::Workflow;
use EPrints::Workflow::Stage;
use EPrints::XML::EPC;

our $__loaded;
our $__cloned;

=pod

=item $ep = EPrints->new();

Construct a new EPrints system object.

=cut

# opts can be 
#  cleanup (default 1) set to zero to prevent garbage collection destroying
#  the repositories we handed out.
sub new($%)
{
	my( $class, %opts ) = @_;

	# mod_perl
	return $EPrints::HANDLE if defined $EPrints::HANDLE;

	return bless { opts=>\%opts }, $class;
}

sub CLONE
{
	my( $class ) = @_;

	print STDERR "Warning! Running EPrints under threads is experimental and liable to break\n";
	$__cloned = 1;

	# we can't re-init here because Perl segfaults if we attempt to opendir()
	# during CLONE()
}

=pod

=item $repo = $ep->repository( $repository_id, %options );

Return the repository with the given ID, or undef. Options are... optional.

Options noise=>1, etc.

=cut

sub repository($$%)
{
	my( $self, $repository_id, %options ) = @_;

	my $ok = 0;
	foreach my $an_id ( $self->repository_ids )
	{
		$ok = 1 if( $an_id eq $repository_id );
	}
	return undef if( !$ok );

	return EPrints::Repository->new( $repository_id, %options );
}	


=pod

=item $repo = $ep->current_repository( %options );

Return the repository based on the current web request, or undef.

%options as for $ep->repository(..)

=cut

sub current_repository($%)
{
	my( $self, %options ) = @_;

	if( $__cloned )
	{
		$__cloned = 0;
		foreach my $repo (values %{$EPrints::HANDLE->{repository}})
		{
			$repo->init_from_thread();
		}
	}

	my $request = EPrints::Apache::AnApache::get_request();
	return undef if !defined $request;
		
	my $repoid = $request->dir_config( "EPrints_ArchiveID" );
	return undef if !defined $repoid;
	
	my $repository = $self->{repository}->{$repoid};
	return undef if !defined $repository;

	$repository->init_from_request( $request );

	return $repository;
}


sub import
{
	my( $class, @args ) = @_;

	my %opts = map { $_ => 1 } @args;

	# mod_perl will probably be running as root for the main httpd.
	# The sub processes should run as the same user as the one specified
	# in $EPrints::SystemSettings
	# An exception to this is running as root (uid==0) in which case
	# we can become the required user.
	if( !$__loaded && !$opts{"no_check_user"} && !$ENV{MOD_PERL} && !$ENV{EPRINTS_NO_CHECK_USER} )
	{
		EPrints::Platform::test_uid();
	}

	$__loaded = 1;
}

=item @ids = $eprints->repository_ids

Returns a list of the active repository ids.

=cut

sub repository_ids
{
	my( $self ) = @_;

	my @ids;

	return EPrints::Config::get_repository_ids();
}

sub load_repositories
{
	my( $self ) = @_;

	my @ids;

	foreach my $id ( $self->repository_ids )
	{
		$self->{repository}->{$id} = $self->repository( $id, db_connect => 0 );
		push @ids, $id;
	}

	return @ids;
}

sub sigusr2_cluck
{
	Carp::cluck( "caught SIGUSR2" );
	$SIG{'USR2'} = \&sigusr2_cluck;
}

# If the signal doesn't exist, it isn't critical so don't warn
{
	no warnings;
	$SIG{'USR2'} = \&sigusr2_cluck;
};

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::Repository>

=head1 COPYRIGHT

__COPYRIGHT__

Copyright 2000-2008 University of Southampton. All Rights Reserved.

__LICENSE__
