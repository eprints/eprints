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

	#!/usr/bin/perl -w -I/opt/eprints3/perl_lib
	
	use EPrints;
	use strict;
	
	my $handle = new EPrints::Handle( 1 , 'my_repository_id' );
	exit( 1 ) unless( defined $handle );

	$eprint = new EPrints::DataObj::EPrint( $handle, 23 );
	my $title = $eprint->get_value( 'title' );
	
	$eprint->set_value( 'creators', 
		[
			{ 
				name => { given=>'John', family=>'Smith' },
				id => 'js@example.com',
			},
			{ 
				name => { given=>'Marvin', family=>'Fenderson' },
				id => 'marvin@totl.net',
			},
		]
	);
	$eprint->commit;

	my $eprint_ds = $handle->get_dataset( "eprint" );
	my $new_eprint = $eprint_ds->create_object( 
		$handle, { title=>"My new EPrint!" } );
	
	my $archive_ds = $handle->get_dataset( "archive" );
	my $search = new EPrints::Search( 
		handle => $handle, 
		dataset => $archive_ds );
	my $date_mf = $archive_ds->get_field( "date" );
	$search->add_field( $date_mf, "2000-2003" );

	my $list = $search->perform_search;
	$list->map(
		sub {
			my( $handle, $dataset, $eprint, $info ) = @_;
	
			printf( "%s: %s\n", 
				 $eprint->get_value( "date" ),
				 $eprint->get_value( "title" ) );
		}
	);
	$list->dispose();

	$handle->log( "We did some stuff." );

	if( some_test() ) { EPrints::abort( "Something bad happened" ); }
	
	$handle->terminate;

=head1 DESCRIPTION

Using this module will cause all the other EPrints modules to be used also.

See http://www.eprints.org/ for more information about EPrints. Much more documentation can be found at http://wiki.eprints.org/w/Documentation

=head2 Key API EPrints Modules

=over 4

=item EPrints

This module! Used to load the other modules.

=item EPrints::DataObj

Abstract object representing a single record in a DataSet. Has one subclass for each type of DataSet. The most important subclasses are listed below. This module documents generic functions which work on all (or most) data objects. Every DataObj has a unique ID within the dataset (an integer, with the exception of Subject). Every DataObj is given a URI of the form I<repository_url>/id/I<datasetid>/I<dataobj_id>

=item EPrints::DataObj::Document

Represents a single document. A document is a set of metadata plus files. It *may* have some repository configuraed metadata in addition to the default. The metadata describes the document and is mostly concerned with formats, and rights. Documents belong to exactly one EPrints::DataObj::EPrint are are destroyed if it is destroyed. A document has one or more file. If there's more than one file then they are related, like a .css file for a .html

=item EPrints::DataObj::EPrint

Represents a single submission to the repository. May have 0+ documents as sub-objects. Has both system defined metafields plus many defined in the repository configuration. 

=item EPrints::DataSet

This object represents a set of objects of the same time, and has associated MetaFields and database tables. A dataset may represent a subset of another dataset. For example, "eprint" represents all EPrints::DataObj::EPrint objects, but the "buffer" dataset only represents those which are "under review".

=item EPrints::Handle

the core of the EPrints API. This object represents a connection between the configuration for a repository, the database connection and either the CGI (web) or CLI (command line) interface.

Handle has a large number of methods, which are documented in more than one file:

=item EPrints::Handle::Language

Handle methods for i18n.

=item EPrints::Handle::Render

Handle methods for generating XHTML as XML::DOM objects.

=item EPrints::Handle::CGI

Handle methods for working with the mod_perl connection.

=item EPrints::Handle::Page

Handle methods for generating and serving XHTML web pages.

=item EPrints::Handle::XML

Handle methods for creating XML::DOM objects.

=item EPrints::List

A list of zero or more data-objects in a single dataset. It can be constructed from a list of ID's or returned as the result of a search.

=item EPrints::MetaField

A single field in a dataset. It has many subclasses, one for each type of field.

=item EPrints::Repository

Represents the configuration, datasets and dataobjects of a single repository. It is loaded from the configuration files and is essentially read-only.

=item EPrints::Search

The search object takes parameters and returns a List object of matching dataobjs from a given dataset. It can also be used it reverse to test if a dataobj matches it's parameters.

=back

=head2 Other API EPrints Modules

=over 4

=item EPrints::Box

A utitility module to render HTML boxes with style and javascript roll-up animations.

=item EPrints::Database

An object representing a connection to the database for a repository. This is an abstraction over sub-objects which connect to MySQL or Oracle.

=item EPrints::DataObj::File

Represents a single file in a document with some basic metadata such as checksums.

=item EPrints::DataObj::User

Represents a single registered user of the repository. Used for keeping track of preferences, profile information and rights management.

=item EPrints::DataObj::Subject

This dataset is used to store the structure of heierachichal(sp?) sets, used by the "Subject" metafield type.

=item EPrints::Email

Tool for sending email.

=item EPrints::Paginate

Tools for rendering an EPrint::List as paginated HTML.

=item EPrints::Paginate::Columns

An extension to EPrints::Paginate which shows the results in sortable columns, as seen in Items and Review screens.

=item EPrints::Platform

Methods to abstract the operating system. Specifically between UNIX and Windows.

=item EPrints::Storage

Methods to abstract the process of reading and writing files. EPrints 3.2 introduced the possibility of storing files in the cloud, or in other storage devices, and this module is the interface to that.

=item EPrints::TempDir

Tools for creating and destorying temporary directories.

=item EPrints::Time

A set of methods for handling time and converting between time formats.

=item EPrints::URL

Utility methods for generating and getting URLs, relative paths etc.

=item EPrints::Utils

Misc. utility methods.

=item EPrints::XML

Utility methods for working with XML and DOM. This papers over the cracks between the 3 different XML DOM libraries EPrints supports.

=back

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

=over 4

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
use EPrints::Paginate;
use EPrints::Paginate::Columns;
use EPrints::Platform;
use EPrints::Plugin;
use EPrints::PluginFactory;
use EPrints::Probity;
use EPrints::Repository;
use EPrints::Search;
use EPrints::Search::Field;
use EPrints::Search::Condition;
use EPrints::CLIProcessor;
use EPrints::ScreenProcessor;
use EPrints::Handle;
use EPrints::Script;
use EPrints::URL;
use EPrints::Paracite;
use EPrints::Update::Static;
use EPrints::Update::Views;
use EPrints::Update::Abstract;
use EPrints::Workflow;
use EPrints::Workflow::Stage;
use EPrints::XML::EPC;

our $__loaded;

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

L<EPrints::Handle>

=head1 COPYRIGHT

__COPYRIGHT__

Copyright 2000-2008 University of Southampton. All Rights Reserved.

__LICENSE__
