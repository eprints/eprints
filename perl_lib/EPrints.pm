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

=head1 METHODS

=over 4

=cut

package EPrints;

use EPrints::SystemSettings;

use Scalar::Util;

BEGIN {
	use Carp qw(cluck);

	use EPrints::Platform;

	umask( 0002 );

	if( $ENV{MOD_PERL} )
	{
		eval '
use Apache::DBI; # must be first! 	 	 
#$Apache::DBI::DEBUG = 3;
use EPrints::Apache::AnApache;
use EPrints::Apache::Login;
use EPrints::Apache::Auth;
use EPrints::Apache::Rewrite;
use EPrints::Apache::VLit;
use EPrints::Apache::Template;
use EPrints::Apache::Storage;
1;';
		if( $@ ) { abort( $@ ); }
	}

	# abort($err) Defined here so modules can abort even at startup
######################################################################
=pod

=item EPrints::abort( $msg )

Print an error message and exit. If running under mod_perl then
print the error as a webpage and exit.

This subroutine is loaded before other modules so that it may be
used to report errors when initialising modules.

=cut
######################################################################

	sub abort
	{
		my( $errmsg ) = @_;

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
use EPrints::Utils;
use EPrints::Time;
use EPrints::Config;
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
use EPrints::Paginate;
use EPrints::Paginate::Columns;
use EPrints::Probity;
use EPrints::Repository;
use EPrints::Search;
use EPrints::Search::Field;
use EPrints::Search::Condition;
use EPrints::CLIProcessor;
use EPrints::ScreenProcessor;
use EPrints::Session;
use EPrints::Script;
use EPrints::URL;
use EPrints::Paracite;
use EPrints::Update::Static;
use EPrints::Update::Views;
use EPrints::Update::Abstract;
use EPrints::Workflow;
use EPrints::Workflow::Stage;
use EPrints::Workflow::Processor;
use EPrints::XML::EPC;

# Load EPrints::Plugin last, because dynamically loaded plugins may have
# EPrints dependencies
use EPrints::Plugin;

sub import
{
	my( $class, @args ) = @_;

	my %opts = map { $_ => 1 } @args;

	# mod_perl will probably be running as root for the main httpd.
	# The sub processes should run as the same user as the one specified
	# in $EPrints::SystemSettings
	# An exception to this is running as root (uid==0) in which case
	# we can become the required user.
	if( !$opts{"no_check_user"} && !$ENV{MOD_PERL} && !$ENV{EPRINTS_NO_CHECK_USER} )
	{
		EPrints::Platform::test_uid();
	}
}

1;

__END__

=back

=head1 SEE ALSO

L<EPrints::Session>

=head1 COPYRIGHT

__COPYRIGHT__

Copyright 2000-2008 University of Southampton. All Rights Reserved.

__LICENSE__
