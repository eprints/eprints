######################################################################
#
# EPrints::Session
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

B<EPrints::Session> - Single connection to the EPrints system

=head1 DESCRIPTION

This module is not really a session. The name is out of date, but
hard to change.

EPrints::Session represents a connection to the EPrints system. It
connects to a single EPrints repository, and the database used by
that repository. Thus it has an associated EPrints::Database and
EPrints::Repository object.

Each "session" has a "current language". If you are running in a 
multilingual mode, this is used by the HTML rendering functions to
choose what language to return text in.

The "session" object also knows about the current apache connection,
if there is one, including the CGI parameters. 

If the connection requires a username and password then it can also 
give access to the EPrints::DataObj::User object representing the user who is
causing this request. 

The session object also provides many methods for creating XHTML 
results which can be returned via the web interface. 

Specific sets of functions are documented in:

=over 4

=item EPrints::Session::XML

=item EPrints::Session::Render

=item EPrints::Session::Language

=item EPrints::Session::Page

=item EPrints::Session::CGI

=back

=head1 METHODS

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{repository}
#     The EPrints::Repository object this session relates to.
#
#  $self->{database}
#     A EPrints::Database object representing this session's connection
#     to the database.
#
#  $self->{noise}
#     The "noise" level which this connection should run at. Zero 
#     will produce only error messages. Higher numbers will produce
#     more warnings and commentary.
#
#  $self->{request}
#     A mod_perl object representing the request to apache, if any.
#
#  $self->{query}
#     A CGI.pm object also representing the request, if any.
#
#  $self->{offline}
#     True if this is a command-line script.
#
#  $self->{doc}
#     A XML DOM document object. All XML created by this session will
#     be part of this document.
#
#  $self->{page}
#     Used to store the output XHTML page between "build_page" and
#     "send_page"
#
#  $self->{lang}
#     The current language that this session should use. eg. "en" or "fr"
#     It is used to determine which phrases and template will be used.
#
######################################################################

package EPrints::Session;

use EPrints;
use EPrints::Session::XML;
use EPrints::Session::Render;
use EPrints::Session::Language;
use EPrints::Session::Page;
use EPrints::Session::CGI;

#use URI::Escape;
use CGI qw(-compile);

use strict;
#require 'sys/syscall.ph';



######################################################################
=pod

=over 4

=item $session = EPrints::Session->new( $mode, [$repository_id], [$noise], [$nocheckdb] )

Create a connection to an EPrints repository which provides access 
to the database and to the repository configuration.

This method can be called in two modes. Setting $mode to 0 means this
is a connection via a CGI web page. $repository_id is ignored, instead
the value is taken from the "PerlSetVar EPrints_ArchiveID" option in
the apache configuration for the current directory.

If this is being called from a command line script, then $mode should
be 1, and $repository_id should be the ID of the repository we want to
connect to.

$mode :
mode = 0    - We are online (CGI script)
mode = 1    - We are offline (bin script) $repository_id is repository_id
mode = 2    - We are online, but don't create a CGI query (so we
 don't consume the data).

$noise is the level of debugging output.
0 - silent
1 - quietish
2 - noisy
3 - debug all SQL statements
4 - debug database connection
 
Under normal conditions use "0" for online and "1" for offline.

$nocheckdb - if this is set to 1 then a connection is made to the
database without checking that the tables exist. 

=cut
######################################################################

sub new
{
	my( $class, $mode, $repository_id, $noise, $nocheckdb ) = @_;
	my $self = {};
	bless $self, $class;

	$mode = 0 unless defined( $mode );
	$noise = 0 unless defined( $noise );
	$self->{noise} = $noise;
	$self->{used_phrases} = {};

	if( $mode == 0 || $mode == 2 || !defined $mode )
	{
		$self->{request} = EPrints::Apache::AnApache::get_request();
		$self->{offline} = 0;
		$self->{repository} = EPrints::Repository->new_from_request( $self->{request} );
	}
	elsif( $mode == 1 )
	{
		$self->{offline} = 1;
		if( !defined $repository_id || $repository_id eq "" )
		{
			print STDERR "No repository id specified.\n";
			return undef;
		}
		$self->{repository} = EPrints::Repository->new( $repository_id );
		if( !defined $self->{repository} )
		{
			print STDERR "Can't load repository module for: $repository_id\n";
			return undef;
		}
	}
	else
	{
		print STDERR "Unknown session mode: $mode\n";
		return undef;
	}

	#### Got Repository Config Module ###

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Session.\n"; }

	$self->_add_http_paths;

	if( $self->{offline} )
	{
		# Set a script to use the default language unless it 
		# overrides it
		$self->change_lang( 
			$self->{repository}->get_conf( "defaultlanguage" ) );
	}
	else
	{
		# running as CGI, Lets work out what language the
		# client wants...
		$self->change_lang( get_session_language( 
			$self->{repository}, 
			$self->{request} ) );
	}
	
	$self->{doc} = EPrints::XML::make_document;

	# Create a database connection
	if( $self->{noise} >= 2 ) { print "Connecting to DB ... "; }
	$self->{database} = EPrints::Database->new( $self );
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->html_phrase( 
			"lib/session:fail_db_connect" ) );
#$self->get_repository->log( "Failed to connect to database." );
		return undef;
	}

	#cjg make this a method of EPrints::Database?
	unless( $nocheckdb )
	{
		# Check there are some tables.
		# Well, check for the most important table, which 
		# if it's not there is a show stopper.
		unless( $self->{database}->is_latest_version )
		{ 
			my $cur_version = $self->{database}->get_version || "unknown";
			if( $self->{database}->has_table( "eprint" ) )
			{	
				EPrints::abort(
	"Database tables are in old configuration (version $cur_version). Please run:\nepadmin upgrade ".$self->get_repository->get_id );
			}
			else
			{
				EPrints::abort(
					"No tables in the MySQL database! ".
					"Did you run create_tables?" );
			}
			$self->{database}->disconnect();
			return undef;
		}
	}

	$self->{storage} = EPrints::Storage->new( $self );

	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	if( $mode == 0 ) { $self->read_params; }

	$self->{repository}->call( "session_init", $self, $self->{offline} );

	return( $self );
}

# add the relative paths + http_* config if not set already by cfg.d
sub _add_http_paths
{
	my( $self ) = @_;

	my $config = $self->{repository}->{config};

	$config->{"rel_path"} = $self->get_url(
		path => "static",
	);
	$config->{"rel_cgipath"} = $self->get_url(
		path => "cgi",
	);
	$config->{"http_url"} ||= $self->get_url(
		scheme => "http",
		host => 1,
		path => "static",
	);
	$config->{"http_cgiurl"} ||= $self->get_url(
		scheme => "http",
		host => 1,
		path => "cgi",
	);
	$config->{"https_url"} ||= $self->get_url(
		scheme => "https",
		host => 1,
		path => "static",
	);
	$config->{"https_cgiurl"} ||= $self->get_url(
		scheme => "https",
		host => 1,
		path => "cgi",
	);
}

######################################################################
=pod

=item $session->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	
	$self->{repository}->call( "session_close", $self );
	$self->{database}->disconnect();

	# If we've not printed the XML page, we need to dispose of
	# it now.
	EPrints::XML::dispose( $self->{doc} );

	if( $self->{noise} >= 2 ) { print "Ending EPrints Session.\n\n"; }

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}





######################################################################
# 
# $id = $session->get_next_id
#
# Return a number unique within this session. Used to generate id's
# in the HTML.
#
# DO NOT use this to generate anything other than id's for use in the
# workflow. Some tools will need to reset this value when the workflow
# is generated more than once in a single session.
#
######################################################################

sub get_next_id
{
	my( $self ) = @_;

	if( !defined $self->{id_counter} )
	{
		$self->{id_counter} = 1;
	}

	return $self->{id_counter}++;
}







######################################################################
=pod

=item $db = $session->get_database

Return the current EPrints::Database connection object.

=cut
######################################################################
sub get_db { return $_[0]->get_database; } # back compatibility

sub get_database
{
	my( $self ) = @_;
	return $self->{database};
}

=item $store = $session->get_storage

Return the storage control object.

=cut

sub get_storage
{
	my( $self ) = @_;
	return $self->{storage};
}



######################################################################
=pod

=item $repository = $session->get_repository

Return the EPrints::Repository object associated with the Session.

=cut
######################################################################

sub get_repository
{
	my( $self ) = @_;
	return $self->{repository};
}

######################################################################
=pod

=item $conf = $session->get_conf( $conf_id, ... )

This is an alias for $session->get_repository->get_conf( ... ) to make for more readable code.

=cut
######################################################################

sub get_conf
{
	my( $self, @params ) = @_;

	return $self->{repository}->get_conf( @params );
}


######################################################################
=pod

=item $url = $session->get_url( [ @OPTS ] [, $page] )

Utility method to get various URLs. See L<EPrints::URL>. With no arguments returns the same as get_uri().

	# Return the current static path
	$session->get_url( path => "static" );

	# Return the current cgi path
	$session->get_url( path => "cgi" );

	# Return a full URL to the current cgi path
	$session->get_url( host => 1, path => "cgi" );

	# Return a full URL to the static path under HTTP
	$session->get_url( scheme => "http", host => 1, path => "static" );

	# Return a full URL to the image 'foo.png'
	$session->get_url( host => 1, path => "images", "foo.png" );

=cut
######################################################################

sub get_url
{
	my( $self, @opts ) = @_;

	my $url = EPrints::URL->new( session => $self );

	return $url->get( @opts );
}


######################################################################
=pod

=item $noise_level = $session->get_noise

Return the noise level for the current session. See the explaination
under EPrints::Session->new()

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=item $boolean = $session->get_online

Return true if this script is running via CGI, return false if we're
on the command line.

=cut
######################################################################

sub get_online
{
	my( $self ) = @_;
	
	return( !$self->{offline} );
}




######################################################################
=pod

=item $plugin = $session->plugin( $pluginid )

Return the plugin with the given pluginid, in this repository or, failing
that, from the system level plugins.

=cut
######################################################################

sub plugin
{
	my( $self, $pluginid, %params ) = @_;

	return $self->get_repository->get_plugin_factory->get_plugin( $pluginid,
		%params,
		session => $self,
		);
}



######################################################################
=pod

=item @plugin_ids  = $session->plugin_list( %restrictions )

Return either a list of all the plugins available to this repository or
return a list of available plugins which can accept the given 
restrictions.

Restictions:
 vary depending on the type of the plugin.

=cut
######################################################################

sub plugin_list
{
	my( $self, %restrictions ) = @_;

	return
		map { $_->get_id() }
		$self->{repository}->get_plugin_factory->get_plugins(
			{ session => $self },
			%restrictions,
		);
}

=item @plugins = $session->get_plugins( [ $params, ] %restrictions )

Returns a list of plugin objects that conform to %restrictions (may be empty).

If $params is given uses that hash reference to initialise the plugins. Always passes this session to the plugin constructor method.

=cut

sub get_plugins
{
	my( $self, @opts ) = @_;

	my $params = scalar(@opts) % 2 ?
		shift(@opts) :
		{};

	$params->{session} = $self;

	return $self->{repository}->get_plugin_factory->get_plugins( $params, @opts );
}



######################################################################
# =pod
# 
# =item $spec = $session->get_citation_spec( $dataset, [$ctype] )
# 
# Return the XML spec for the given dataset. If a $ctype is specified
# then return the named citation style for that dataset. eg.
# a $ctype of "foo" on the eprint dataset gives a copy of the citation
# spec with ID "eprint_foo".
# 
# This returns a copy of the XML citation spec., so that it may be 
# safely modified.
# 
# =cut
######################################################################

sub get_citation_spec
{
	my( $self, $dataset, $ctype ) = @_;

	my $ds_id = $dataset->confid();

	my $citespec = $self->{repository}->get_citation_spec( 
				$ds_id,
				$ctype );

	if( !defined $citespec )
	{
		return $self->make_text( "Error: Unknown Citation Style \"$ds_id.$ctype\"" );
	}
	
	my $r = $self->clone_for_me( $citespec, 1 );

	return $r;
}

sub get_citation_type
{
	my( $self, $dataset, $ctype ) = @_;

	my $ds_id = $dataset->confid();

	return $self->{repository}->get_citation_type( 
				$ds_id,
				$ctype );
}


######################################################################
=pod

=item $time = EPrints::Session::microtime();

This function is currently buggy so just returns the time in seconds.

Return the time of day in seconds, but to a precision of microseconds.

Accuracy depends on the operating system etc.

=cut
######################################################################

sub microtime
{
        # disabled due to bug.
        return time();

        my $TIMEVAL_T = "LL";
	my $t = "";
	my @t = ();

        $t = pack($TIMEVAL_T, ());

	syscall( &SYS_gettimeofday, $t, 0) != -1
                or die "gettimeofday: $!";

        @t = unpack($TIMEVAL_T, $t);
        $t[1] /= 1_000_000;

        return $t[0]+$t[1];
}



######################################################################
=pod

=item $foo = $session->mail_administrator( $subjectid, $messageid, %inserts )

Sends a mail to the repository administrator with the given subject and
message body.

$subjectid is the name of a phrase in the phrase file to use
for the subject.

$messageid is the name of a phrase in the phrase file to use as the
basis for the mail body.

%inserts is a hash. The keys are the pins in the messageid phrase and
the values the utf8 strings to replace the pins with.

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	
	# Mail the admin in the default language
	my $langid = $self->{repository}->get_conf( "defaultlanguage" );
	return EPrints::Email::send_mail(
		session => $self,
		langid => $langid,
		to_email => $self->{repository}->get_conf( "adminemail" ),
		to_name => $self->phrase( "lib/session:archive_admin" ),	
		from_email => $self->{repository}->get_conf( "adminemail" ),
		from_name => $self->phrase( "lib/session:archive_admin" ),	
		subject =>  EPrints::Utils::tree_to_utf8(
			$self->html_phrase( $subjectid ) ),
		message => $self->html_phrase( $messageid, %inserts ) );
}



my $PUBLIC_PRIVS =
{
	"eprint_search" => 1,
};

sub allow_anybody
{
	my( $session, $priv ) = @_;

	return 1 if( $PUBLIC_PRIVS->{$priv} );

	return 0;
}



######################################################################
=pod

=item $session->DESTROY

Destructor. Don't call directly.

=cut
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	EPrints::Utils::destroy( $self );
}


sub cache_subjects
{
  my( $self ) = @_;

  ( $self->{subject_cache}, $self->{subject_child_map} ) =
    EPrints::DataObj::Subject::get_all( $self );
    $self->{subjects_cached} = 1;
}

######################################################################
=pod

=back

=cut

######################################################################



1;


