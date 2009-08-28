######################################################################
#
# EPrints::RepositoryHandle
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

B<EPrints::RepositoryHandle> - Single connection to the EPrints system

=head1 SYNOPSIS

	# cgi script	
	$handle = EPrints->get_repository_handle();
	exit( 1 ) unless( defined $handle );

	# bin script
	$handle = EPrints->get_repository_handle_by_id( $repository_id, noise => $noise );

	$dataset = $handle->get_dataset( $dataset_id );
	$handle->log( "Something bad occurred" );
	$conf = $handle->get_conf( "base_url" );

	$eprint = $handle->get_eprint( $eprint_id );

	$user = $handle->get_user( $user_id );
	$user = $handle->get_user_with_username( $username );
	$user = $handle->get_user_with_email( $email );

	$subject = $handle->get_subject( $subject_id );


	## CGI Methods

	my $user = $handle->current_user;
	EPrints::abort() unless( defined $user );

	my $epid = $handle->param( "eprintid" );

	$handle->redirect( "http://www.eprints.org/" );

	my $current_page_uri = $handle->get_uri();


	## Language Methods

	EPrints::RepositoryHandle::get_language( $my_repository, $request ); 
	# returns "en" country code for english

	$handle->change_lang( "de" ) # sets the language to German

	# Return a DOM object containing the archivename phrase for the current repository.
	$name_dom = $handle->html_phrase("archivename"); 

	# Return a string containing the text of the phrase 
	$name_text = $handle->phrase("archivename"); 


	# Page Methods (need moving yet)

	$handle->prepare_page( { page=>$mypage, title=>$mytitle } );
	$handle->send_page(); 

=head1 DESCRIPTION

EPrints::RepositoryHandle represents a connection to the EPrints system. It
connects to a single EPrints repository, and the database used by
that repository. Thus it has an associated EPrints::Database and
EPrints::Repository object.

Each "handle" has a current language. If you are running in a 
multilingual mode, this is used by the HTML rendering functions to
choose what language to return text in. See EPrints::RepositoryHandle::Language for
the language specific methods.

The "handle" object also knows about the current apache connection,
if there is one, including the CGI parameters. 

If the connection requires a username and password then it can also 
give access to the EPrints::DataObj::User object representing the user who is
causing this request. 

The handlhandle object also provides many methods for creating XHTML 
results which can be returned via the web interface. 

Specific sets of functions are documented in:

=over 8

L<EPrints::RepositoryHandle::XML> - XML DOM utilties.  

L<EPrints::RepositoryHandle::Render> - XHTML generating utilities.  

L<EPrints::RepositoryHandle::Language> - I18L methods.  

L<EPrints::RepositoryHandle::Page> - XHTML Page and templating methods.  

L<EPrints::RepositoryHandle::CGI> - Methods for detail with the web-interface.  

=back

=head1 METHODS

These are general methods, not documented in the above modules.

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{repository}
#     The EPrints::Repository object this handle relates to.
#
#  $self->{database}
#     A EPrints::Database object representing this handle's connection
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
#  $self->{xml}
#     A XMLHandle object used to create XML and XHTML.
#
#  $self->{lang}
#     The current language that this handle should use. eg. "en" or "fr"
#     It is used to determine which phrases and template will be used.
#
######################################################################


package EPrints::RepositoryHandle;

use EPrints;

#use URI::Escape;
use CGI qw(-compile);

use strict;
#require 'sys/syscall.ph';

######################################################################
# $handle = EPrints::RepositoryHandle->new( %opts )
# 
# See EPrints.pm for details.
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	$opts{check_database} = 1 if( !defined $opts{check_database} );
	$opts{consume_post_data} = 1 if( !defined $opts{consume_post_data} );
	$opts{noise} = 0 if( !defined $opts{noise} );

	my $self = {};
	bless $self, $class;

	$self->{noise} = $opts{noise};
	$self->{used_phrases} = {};

	if( defined $opts{repository} )
	{
		$self->{offline} = 1;
		$self->{repository} = EPrints->get_repository_config( $opts{repository} );
		if( !defined $self->{repository} )
		{
			print STDERR "Can't load repository module for: ".$opts{repository}."\n";
			return undef;
		}
		$opts{consume_post_data} = 0;
	}
	else
	{
		if( !$ENV{MOD_PERL} )
		{
			EPrints::abort( "No repository specified, but not running under mod_perl." );
		}
		$self->{request} = EPrints::Apache::AnApache::get_request();
		$self->{offline} = 0;
		$self->{repository} = EPrints::Repository->new_from_request( $self->{request} );
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
		$self->change_lang( get_language( 
			$self->{repository}, 
			$self->{request} ) );
	}
	
	$self->{xml} = EPrints::XMLHandle->new( $self );

	# Create a database connection
	if( $self->{noise} >= 2 ) { print "Connecting to DB ... "; }
	$self->{database} = EPrints::Database->new( $self );
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->html_phrase( 
			"lib/session:fail_db_connect" ) );
		return undef;
	}

	# Check there are some tables.
	# Well, check for the most important table, which 
	# if it's not there is a show stopper.
	if( $opts{check_database} && !$self->{database}->is_latest_version )
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
	"No tables in the MySQL database! Did you run create_tables?" );
		}
		$self->{database}->disconnect();
		return undef;
	}

	$self->{storage} = EPrints::Storage->new( $self );

	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	if( $opts{consume_post_data} ) { $self->read_params; }

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

=over 8

=item $handle->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	$self->{repository}->call( "session_close", $self );
	if( defined $self->{database} )
	{
		$self->{database}->disconnect();
		delete $self->{database};
	}
	if( defined $self->{xml} )
	{
		$self->{xml}->dispose();
		delete $self->{xml};
	}

	if( $self->{noise} >= 2 ) { print "Ending EPrints Session.\n\n"; }

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}





######################################################################
# 
# $id = $handle->get_next_id
#
# Return a number unique within this handle. Used to generate id's
# in the HTML.
#
# DO NOT use this to generate anything other than id's for use in the
# workflow. Some tools will need to reset this value when the workflow
# is generated more than once in a single handle.
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

=item $db = $handle->get_database

Return the current EPrints::Database connection object.

=cut
######################################################################

sub get_database
{
	my( $self ) = @_;
	return $self->{database};
}

=item $store = $handle->get_storage

Return the storage control object. See EPrints::Storage for details.

=cut

sub get_storage
{
	my( $self ) = @_;
	return $self->{storage};
}



######################################################################
=pod

=item $repository = $handle->get_repository

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

=item $dataset = $handle->get_dataset( $dataset_id )

This is an alias for $handle->get_repository->get_dataset( $dataset_id ) to make for more readable code.

Returns the named EPrints::DataSet for the repository or undef.

=cut
######################################################################

sub get_dataset
{
	my( $self, $dataset_id ) = @_;

	return $self->{repository}->get_dataset( $dataset_id );
}

######################################################################
=pod

=item $object = $handle->get_dataobj( $dataset_id, $object_id )

This is an alias for $handle->get_repository->get_dataset( $dataset_id )->get_object( $handle, $object_id ) to make for more readable code.

Returns the EPrints::DataObj for the specified dataset and object_id or undefined if either the dataset or object do not exist.

=cut
######################################################################

sub get_dataobj
{
	my( $self, $dataset_id, $object_id ) = @_;

	my $ds = $self->{repository}->get_dataset( $dataset_id, $object_id );

	return unless defined $ds;

	return $ds->get_object( $object_id );
}

######################################################################
=pod

=item $eprint = $handle->get_live_eprint( $eprint_id )

Return an eprint which is publically available (ie. in the "archive"
dataset). Use this in preference to $handle->get_eprint if you are 
making scripts where the output will be shown to the public.

Returns undef if the eprint does not exist, or is not public.

=cut
######################################################################

sub get_live_eprint
{
	my( $self, $eprint_id ) = @_;

	return $self->{repository}->{datasets}->{"archive"}->{class}->new( $self, $eprint_id );
}

######################################################################
=pod

=item $eprint = $handle->get_user_with_username( $username )

Return a user dataobj with the given username, or undef.

=cut
######################################################################

sub get_user_with_username
{
	my( $self, $username ) = @_;

	return EPrints::DataObj::User::user_with_username( $self, $username );
}

######################################################################
=pod

=item $eprint = $handle->get_user_with_email( $email )

Return a user dataobj with the given email, or undef.

=cut
######################################################################

sub get_user_with_email
{
	my( $self, $email ) = @_;

	return EPrints::DataObj::User::user_with_email( $self, $email );
}

######################################################################
=pod

=item $eprint = $handle->get_eprint( $eprint_id )

=item $user = $handle->get_user( $user_id )

=item $document = $handle->get_document( $document_id )

=item $file = $handle->get_file( $file_id )

=item $subject = $handle->get_subject( $subject_id )

This is an alias for $handle->get_dataset( ... )->get_object( ... ) to make for more readable code.

Any dataset may be accessed in this manner, but only the ones listed above should be considered part of the API.

=cut
######################################################################

sub AUTOLOAD
{
	my( $self, @params ) = @_;

	our $AUTOLOAD;

	if( $AUTOLOAD =~ m/^.*::get_(.*)$/ )
	{
		my $ds = $self->{repository}->{datasets}->{$1};
		if( defined $ds && defined $ds->{class} )
		{
			return $ds->{class}->new( $self, @params );
		}
	}

	EPrints::abort( "Unknown method '$AUTOLOAD' called on EPrints::RepositoryHandle" );
}

######################################################################
=pod

=item $handle->log( $conf_id, ... )

This is an alias for $handle->get_repository->log( ... ) to make for more readable code.

Write a message to the current log file.

=cut
######################################################################

sub log
{
	my( $self, @params ) = @_;

	$self->{repository}->log( @params );
}

######################################################################
=pod

=item $confitem = $handle->get_conf( $key, [@subkeys] )

This is an alias for $handle->get_repository->get_conf( ... ) to make for more readable code.

Return a configuration value. Can go deeper down a tree of parameters.

eg. if 
	$conf = $handle->get_conf( "a" );
returns { b=>1, c=>2, d=>3 } then
	$conf = $handle->get_conf( "a","c" );
will return 2.

=cut
######################################################################

sub get_conf
{
	my( $self, @params ) = @_;

	return $self->{repository}->get_conf( @params );
}


######################################################################
=pod

=item $url = $handle->get_url( [ @OPTS ] [, $page] )

Utility method to get various URLs. See L<EPrints::URL>. With no arguments returns the same as get_uri().

	# Return the current static path
	$handle->get_url( path => "static" );

	# Return the current cgi path
	$handle->get_url( path => "cgi" );

	# Return a full URL to the current cgi path
	$handle->get_url( host => 1, path => "cgi" );

	# Return a full URL to the static path under HTTP
	$handle->get_url( scheme => "http", host => 1, path => "static" );

	# Return a full URL to the image 'foo.png'
	$handle->get_url( host => 1, path => "images", "foo.png" );

=cut
######################################################################

sub get_url
{
	my( $self, @opts ) = @_;

	my $url = EPrints::URL->new( handle => $self );

	return $url->get( @opts );
}


######################################################################
=pod

=item $noise_level = $handle->get_noise

Return the noise level for the current handle. See the explaination
under EPrints->get_repository_handle()

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=item $boolean = $handle->get_online

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

=item $plugin = $handle->plugin( $pluginid )

Return the plugin with the given pluginid, in this repository or, failing
that, from the system level plugins.

=cut
######################################################################

sub plugin
{
	my( $self, $pluginid, %params ) = @_;

	return $self->get_repository->get_plugin_factory->get_plugin( $pluginid,
		%params,
		handle => $self,
		);
}



######################################################################
# @plugin_ids  = $handle->plugin_list( %restrictions )
# 
# Return either a list of all the plugins available to this repository or
# return a list of available plugins which can accept the given 
# restrictions.
# 
# Restictions:
#  vary depending on the type of the plugin.
######################################################################

sub plugin_list
{
	my( $self, %restrictions ) = @_;

	return
		map { $_->get_id() }
		$self->{repository}->get_plugin_factory->get_plugins(
			{ handle => $self },
			%restrictions,
		);
}

######################################################################
# @plugins = $handle->get_plugins( [ $params, ] %restrictions )
# 
# Returns a list of plugin objects that conform to %restrictions (may be empty).
# 
# If $params is given uses that hash reference to initialise the 
# plugins. Always passes this handle to the plugin constructor method.
######################################################################

sub get_plugins
{
	my( $self, @opts ) = @_;

	my $params = scalar(@opts) % 2 ?
		shift(@opts) :
		{};

	$params->{handle} = $self;

	return $self->{repository}->get_plugin_factory->get_plugins( $params, @opts );
}



######################################################################
# $spec = $handle->get_citation_spec( $dataset, [$ctype] )
# 
# Return the XML spec for the given dataset. If a $ctype is specified
# then return the named citation style for that dataset. eg.
# a $ctype of "foo" on the eprint dataset gives a copy of the citation
# spec with ID "eprint_foo".
# 
# This returns a copy of the XML citation spec., so that it may be 
# safely modified.
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
# 
# $time = EPrints::RepositoryHandle::microtime();
# 
# This function is currently buggy so just returns the time in seconds.
# 
# Return the time of day in seconds, but to a precision of microseconds.
# 
# Accuracy depends on the operating system etc.
# 
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

=item $ok = $handle->mail_administrator( $subjectid, $messageid, %inserts )

Sends a mail to the repository administrator with the given subject and
message body.

$subjectid is the name of a phrase in the phrase file to use
for the subject.

$messageid is the name of a phrase in the phrase file to use as the
basis for the mail body.

%inserts is a hash. The keys are the pins in the messageid phrase and
the values the utf8 strings to replace the pins with.

Returns true on success, false on failure.

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	
	# Mail the admin in the default language
	my $langid = $self->{repository}->get_conf( "defaultlanguage" );
	return EPrints::Email::send_mail(
		handle => $self,
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
	my( $handle, $priv ) = @_;

	return 1 if( $PUBLIC_PRIVS->{$priv} );

	return 0;
}



######################################################################
# 
# $handle->DESTROY
# 
# Destructor. Don't call directly.
# 
######################################################################

sub DESTROY
{
	my( $self ) = @_;

	if( defined $self->{repository} ) 
	{
		$self->terminate;
	}
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
######################################################################
# CGI Methods
######################################################################
######################################################################
=pod

=back

=head1 CGI Methods

=cut
######################################################################


######################################################################
=pod

=over 4

=item $request = $handle->get_request;

Return the Apache request object (from mod_perl) or undefined if 
this isn't a CGI script.

=cut
######################################################################

sub get_request
{
	my( $self ) = @_;

	return $self->{request};
}

######################################################################
=pod

=item $query = $handle->get_query;

Return the CGI.pm object describing the current HTTP query, or 
undefined if this isn't a CGI script.

=cut
######################################################################

sub get_query
{
	my( $self ) = @_;

	return $self->{query};
}

######################################################################
=pod

=item $uri = $handle->get_uri

Returns the URL of the current script. Or "undef".

=cut
######################################################################

sub get_uri
{
	my( $self ) = @_;

	return undef unless defined $self->{request};

	return( $self->{"request"}->uri );
}

######################################################################
=pod

=item $uri = $handle->get_full_url

Returns the URL of the current script plus the CGI params.

=cut
######################################################################

sub get_full_url
{
	my( $self ) = @_;

	return undef unless defined $self->{request};

	# we need to add parameters manually to avoid semi-colons
	my $url = URI->new( $self->get_url( host => 1 ) );
	$url->path( $self->{request}->uri );

	my @params = $self->param;
	my @form;
	foreach my $param (@params)
	{
		push @form, map { $param => $_ } $self->param( $param );
	}
	utf8::encode($_) for @form; # utf-8 encoded URL
	$url->query_form( @form );

	return $url;
}

######################################################################
=pod

=item $secure = $handle->get_secure

Returns true if we're using HTTPS/SSL (checks get_online first).

=cut
######################################################################

sub get_secure
{
	my( $self ) = @_;

	# mod_ssl sets "HTTPS", but only AFTER the Auth stage
	return $self->get_online &&
		($ENV{"HTTPS"} || $self->get_request->dir_config( 'EPrints_Secure' ));
}






######################################################################
=pod

=item $handle->redirect( $url, [%opts] )

Redirects the browser to $url.

=cut
######################################################################

sub redirect
{
	my( $self, $url, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{"offline"} )
	{
		print STDERR "ODD! redirect called in offline script.\n";
		return;
	}
	EPrints::Apache::AnApache::send_status_line( $self->{"request"}, 302, "Moved" );
	EPrints::Apache::AnApache::header_out( 
		$self->{"request"},
		"Location",
		$url );

	EPrints::Apache::AnApache::send_http_header( $self->{"request"}, %opts );
}

#######################################################################
#=pod
#
#=item $handle->not_found( [ $message ] )
#
#Send a 404 Not Found header. If $message is undef sets message to
#'Not Found' but does B<NOT> print an error message, otherwise
#defaults to the normal 404 Not Found type response.
#
#=cut
#######################################################################

sub not_found
{
	my( $self, $message ) = @_;

	$message = "Not Found" if @_ == 1;
	
	if( !defined($message) )
	{
		my $r = $self->{request};
		my $c = $r->connection;
	
		# Suppress the normal 404 message if $message is undefined
		$c->notes->set( show_404 => 0 );
		$message = "Not Found";
	}

	EPrints::Apache::AnApache::send_status_line( $self->{"request"}, 404, $message );
}

######################################################################
=pod

=item $handle->send_http_header( %opts )

Send the HTTP header. Only makes sense if this is running as a CGI 
script.

Opts supported are:

content_type. Default value is "text/html; charset=UTF-8". This sets
the http content type header.

lang. If this is set then a cookie setting the language preference
is set in the http header.

=cut
######################################################################

sub send_http_header
{
	my( $self, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{offline} )
	{
		$self->{repository}->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	if( !defined $opts{content_type} )
	{
		$opts{content_type} = 'text/html; charset=UTF-8';
	}
	$self->{request}->content_type( $opts{content_type} );

	$self->set_cookies( %opts );

	EPrints::Apache::AnApache::header_out( 
		$self->{"request"},
		"Cache-Control" => "no-store, no-cache, must-revalidate" );

	EPrints::Apache::AnApache::send_http_header( $self->{request} );
}

sub set_cookies
{
	my( $self, %opts ) = @_;

	my $r = $self->{request};
	my $c = $r->connection;
	
	# from apache notes (cgi script)
	my $code = $c->notes->get( "cookie_code" );
	$c->notes->set( cookie_code=>'undef' );

	# from opts (document)
	$code = $opts{code} if( defined $opts{code} );
	
	if( defined $code && $code ne 'undef')
	{
		my $cookie = $self->{query}->cookie(
			-name    => "eprints_session",
			-path    => "/",
			-value   => $code,
			-domain  => $self->{repository}->get_conf("cookie_domain"),
		);	
		EPrints::Apache::AnApache::header_out( 
			$self->{"request"},
			"Set-Cookie" => $cookie );
	}

	if( defined $opts{lang} )
	{
		my $cookie = $self->{query}->cookie(
			-name    => "eprints_lang",
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{repository}->get_conf("cookie_domain") );
		EPrints::Apache::AnApache::header_out( 
				$self->{"request"},
				"Set-Cookie" => $cookie );
	}
}



######################################################################
=pod

=item $value or @values = $handle->param( $name )

Passes through to CGI.pm param method.

$value = $handle->param( $name ): returns the value of CGI parameter
$name.

$value = $handle->param( $name ): returns the value of CGI parameter
$name.

@values = $handle->param: returns an array of the names of all the
CGI parameters in the current request.

=cut
######################################################################

sub param
{
	my( $self, $name ) = @_;

	if( !defined $self->{query} ) 
	{
		EPrints::abort("CGI Query object not defined!" );
	}

	if( !wantarray )
	{
		my $value = ( $self->{query}->param( $name ) );
		utf8::decode($value);
		return $value;
	}
	
	# Called in an array context
	my @result;

	if( defined $name )
	{
		@result = $self->{query}->param( $name );
	}
	else
	{
		@result = $self->{query}->param;
	}

	utf8::decode($_) for @result;

	return( @result );

}

# $handle->read_params
# 
# If we're online but have not yet read the CGI parameters then this
# will cause handle to read (and consume) them.

# If we're coming from cookie login page then grab the CGI params
# from an apache note set in Login.pm

sub read_params
{
	my( $self ) = @_;

	my $r = $self->{request};
	if( !defined $r ) 
	{ 
		EPrints::abort( "Called \$handle->read_params but no request object available!" ); 
	}

	my $uri = $r->unparsed_uri;
	my $progressid = ($uri =~ /progress_id=([a-fA-F0-9]{32})/)[0];

	my $c = $r->connection;

	my $params = $c->notes->get( "loginparams" );
	if( defined $params && $params ne 'undef')
	{
 		$self->{query} = new CGI( $params ); 
	}
	elsif( defined( $progressid ) && $r->method eq "POST" )
	{
		EPrints::DataObj::UploadProgress->remove_expired( $self );

		my $size = $r->headers_in->get('Content-Length') || 0;

		my $progress = EPrints::DataObj::UploadProgress->create_from_data( $self, {
			progressid => $progressid,
			size => $size,
			received => 0,
		});

		# Something odd happened (user may have stopped/retried)
		if( !defined $progress )
		{
			$self->{query} = new CGI();
		}
		else
		{
			$self->{query} = new CGI( \&EPrints::DataObj::UploadProgress::update_cb, $progress );

			# The CGI callback doesn't include the rest of the POST that
			# Content-Length includes
			$progress->set_value( "received", $size );
			$progress->commit;
		}
	}
	elsif( $r->method eq "PUT" )
	{
		my $buffer;
		while( $r->read( $buffer, 1024*1024 ) )
		{
			$self->{putdata} .= $buffer;
		}
 		$self->{query} = new CGI();
	}
	else
	{
 		$self->{query} = new CGI();
	}

	$c->notes->set( loginparams=>'undef' );
}

######################################################################
=pod

=item $bool = $handle->have_parameters

Return true if the current script had any parameters (post or get)

=cut
######################################################################

sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->param();

	return( scalar @names > 0 );
}





sub logout
{
	my( $self ) = @_;

	$self->{logged_out} = 1;
}

sub reload_current_user
{
	my( $self ) = @_;

	delete $self->{current_user};
}

######################################################################
=pod

=item $user = $handle->current_user

Return the current EPrints::DataObj::User for this handle.

Return undef if there isn't one.

=cut
######################################################################

sub current_user
{
	my( $self ) = @_;

	if( $self->{offline} )
	{
		return undef;
	}

	if( $self->{logged_out} )
	{	
		return undef;
	}

	if( !defined $self->{current_user} )
	{
		return undef if( $self->{already_in_current_user} );
		$self->{already_in_current_user} = 1;

		if( $self->get_repository->can_call( 'get_current_user' ) )
		{
			$self->{current_user} = $self->get_repository->call( 'get_current_user', $self );
		}
		elsif( $self->get_repository->get_conf( "cookie_auth" ) ) 
		{
			$self->{current_user} = $self->_current_user_auth_cookie;
		}
		else
		{
			$self->{current_user} = $self->_current_user_auth_basic;
		}
		$self->{already_in_current_user} = 0;
	}
	return $self->{current_user};
}

sub _current_user_auth_basic
{
	my( $self ) = @_;

	if( !defined $self->{request} )
	{
		# not a cgi script.
		return undef;
	}

	my $username = $self->{request}->user;

	return undef if( !EPrints::Utils::is_set( $username ) );

	return $self->get_user_with_username( $username );
}

# Attempt to login using cookie based login.

# Returns a user on success or undef on failure.

sub _current_user_auth_cookie
{
	my( $self ) = @_;

	if( !defined $self->{request} )
	{
		# not a cgi script.
		return undef;
	}


	# we won't have the cookie for the page after login.
	my $c = $self->{request}->connection;
	my $userid = $c->notes->get( "userid" );
	$c->notes->set( "userid", 'undef' );

	if( EPrints::Utils::is_set( $userid ) && $userid ne 'undef' )
	{	
		return $self->get_user( $userid );
	}
	
	my $cookie = EPrints::Apache::AnApache::cookie( $self->get_request, "eprints_session" );

	return undef if( !defined $cookie );
	return undef if( $cookie eq "" );

	my $remote_addr = $c->get_remote_host;
	
	$userid = $self->{database}->get_ticket_userid( $cookie, $remote_addr );
	
	return undef if( !EPrints::Utils::is_set( $userid ) );

	return $self->get_user( $userid );
}



#######################################################################
#=pod
#
#=item $boolean = $handle->seen_form
#
#Return true if the current request contains the values from a
#form generated by EPrints.
#
#This is identified by a hidden field placed into forms named
#_seen with value "true".
#
#=cut
#######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->param( "_seen" ) &&
	                $self->param( "_seen" ) eq "true" );

	return( $result );
}


#######################################################################
#=pod
#
#=item $boolean = $handle->internal_button_pressed( $buttonid )
#
#Return true if a button has been pressed in a form which is intended
#to reload the current page with some change.
#
#Examples include the "more spaces" button on multiple fields, the 
#"lookup" button on succeeds, etc.
#
#=cut
######################################################################

sub internal_button_pressed
{
	my( $self, $buttonid ) = @_;

	if( defined $buttonid )
	{
		return 1 if( defined $self->param( "_internal_".$buttonid ) );
		return 1 if( defined $self->param( "_internal_".$buttonid.".x" ) );
		return 0;
	}
	
	if( !defined $self->{internalbuttonpressed} )
	{
		my $p;
		# $p = string
		
		$self->{internalbuttonpressed} = 0;

		foreach $p ( $self->param() )
		{
			if( $p =~ m/^_internal/ && EPrints::Utils::is_set( $self->param($p) ) )
			{
				$self->{internalbuttonpressed} = 1;
				last;
			}

		}	
	}

	return $self->{internalbuttonpressed};
}


#######################################################################
#=pod
#
#=item $action_id = $handle->get_action_button
#
#Return the ID of the eprint action button which has been pressed in
#a form, if there was one. The name of the button is "_action_" 
#followed by the id. 
#
#This also handles the .x and .y inserted in image submit.
#
#This is designed to get back the name of an action button created
#by render_action_buttons.
#
#=cut
######################################################################

sub get_action_button
{
	my( $self ) = @_;

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ s/^_action_// )
		{
			$p =~ s/\.[xy]$//;
			return $p;
		}
	}

	# undef if _default is not set.
	$p = $self->param("_default_action");
	return $p if defined $p;

	return "";
}



#######################################################################
#=pod
#
#=item $button_id = $handle->get_internal_button
#
#Return the id of the internal button which has been pushed, or 
#undef if one wasn't.
#
#=cut
#######################################################################

sub get_internal_button
{
	my( $self ) = @_;

	if( defined $self->{internalbutton} )
	{
		return $self->{internalbutton};
	}

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ m/^_internal_/ )
		{
			$p =~ s/\.[xy]$//;
			$self->{internalbutton} = substr($p,10);
			return $self->{internalbutton};
		}
	}

	$self->{internalbutton} = "";
	return $self->{internalbutton};
}

######################################################################
=pod

=item $client = $handle->client

Return a string representing the kind of browser that made the 
current request.

Options are GECKO, LYNX, MSIE4, MSIE5, MSIE6, ?.

GECKO covers mozilla and firefox.

? is what's returned if none of the others were matched.

These divisions are intended for modifying the way pages are rendered
not logging what browser was used. Hence merging mozilla and firefox.

=cut
######################################################################

sub client
{
	my( $self ) = @_;

	my $client = $ENV{HTTP_USER_AGENT};

	# we return gecko, rather than mozilla, as
	# other browsers may use gecko renderer and
	# that's what why tailor output, on how it gets
	# rendered.

	# This isn't very rich in it's responses!

	return "GECKO" if( $client=~m/Gecko/i );
	return "LYNX" if( $client=~m/Lynx/i );
	return "MSIE4" if( $client=~m/MSIE 4/i );
	return "MSIE5" if( $client=~m/MSIE 5/i );
	return "MSIE6" if( $client=~m/MSIE 6/i );

	return "?";
}


######################################################################
=pod

=item $status = $handle->get_http_status

Return the status of the current HTTP request.

=cut
######################################################################

sub get_http_status
{
	my( $self ) = @_;

	return $self->{request}->status();
}

######################################################################
#
# $handle->get_static_page_conf_file
# 
# Utility method to return the config file for the static html page 
# being viewed, if there is one, and it's in the repository config.
#
######################################################################

sub get_static_page_conf_file
{
	my( $handle ) = @_;

	my $repository = $handle->get_repository;

	my $r = $handle->get_request;
	$repository->check_secure_dirs( $r );
	my $esec = $r->dir_config( "EPrints_Secure" );
	my $secure = (defined $esec && $esec eq "yes" );
	my $urlpath;
	if( $secure ) 
	{ 
		$urlpath = $repository->get_conf( "https_root" );
	}
	else
	{ 
		$urlpath = $repository->get_conf( "http_root" );
	}

	my $uri = $r->uri;

	my $lang = EPrints::RepositoryHandle::get_language( $repository, $r );
	my $args = $r->args;
	if( $args ne "" ) { $args = '?'.$args; }

	# Skip rewriting the /cgi/ path and any other specified in
	# the config file.
	my $econf = $repository->get_conf('rewrite_exceptions');
	my @exceptions = ();
	if( defined $econf ) { @exceptions = @{$econf}; }
	push @exceptions,
		"$urlpath/id/",
		"$urlpath/view/",
		"$urlpath/sword-app/",
		"$urlpath/thumbnails/";

	foreach my $exppath ( @exceptions )
	{
		return undef if( $uri =~ m/^$exppath/ );
	}

	return undef if( $uri =~ m!^$urlpath/\d+/! );
	return undef unless( $uri =~ s/^$urlpath// );
	$uri =~ s/\/$/\/index.html/;
	return undef unless( $uri =~ s/\.html$// );

	foreach my $suffix ( qw/ xpage xhtml html / )
	{
		my $conffile = "lang/".$handle->get_langid."/static".$uri.".".$suffix;	
		if( -e $handle->get_repository->get_conf( "config_path" )."/".$conffile )
		{
			return $conffile;
		}
	}

	return undef;
}

# Update the login ticket for the given user
sub login
{
	my( $self,$user ) = @_;

	my $ip = $ENV{REMOTE_ADDR};

        my $code = EPrints::Apache::AnApache::cookie( $self->get_request, "eprints_session" );
	return unless EPrints::Utils::is_set( $code );

	my $userid = $user->get_id;
	$self->{database}->update_ticket_userid( $code, $userid, $ip );

#	my $c = $self->{request}->connection;
#	$c->notes->set(userid=>$userid);
#	$c->notes->set(cookie_code=>$code);
}


#######################################################################
#=pod
#
#=item $result = $handle->valid_login( $username, $password )
#
#Check if $username and $password are valid in the repository. This will
#call the appropriate authentication handler when multiple authentication
#mechanisms are in use (for example LDAP and CAS).
#
#Note that this should only be used by CGI scripts as logging in is 
#otherwise handled internally by EPrints.
#
#=cut
######################################################################

sub valid_login
{
	my( $self, $username, $password ) = @_;

	my $valid_login_handler = sub { 
		my( $handle,$username,$password ) = @_;
		return $handle->get_database->valid_login( $username, $password );
	};
	if( $self->get_repository->can_call( "check_user_password" ) )
	{
		$valid_login_handler = $self->get_repository->get_conf( "check_user_password" );
	}

	return &{$valid_login_handler}( $self, $username, $password );
}





######################################################################
######################################################################
# Language Methods
######################################################################
######################################################################
=pod

=back

=head1 Language Methods

=cut
######################################################################

######################################################################
=pod

=over 4

=item $langid = EPrints::RepositoryHandle::get_language( $repository, $request )

Given an repository object and a Apache (mod_perl) request object, this
method decides what language the handle should be.

First it looks at the HTTP cookie "eprints_lang", failing that it
looks at the prefered language of the request from the HTTP header,
failing that it looks at the default language for the repository.

The language ID it returns is the highest on the list that the given
eprint repository actually supports.

$repository - the Respository object which will be used to determine the supported languages

$request - the Request object which will be used to determine the requested language

e.g EPrints::RepositoryHandle::get_language( $my_repository, $request ); # returns "en" country code for english

=cut
######################################################################

sub get_language
{
	my( $repository, $request ) = @_; #$r should not really be passed???

	my @prefs;

	# IMPORTANT! This function must not consume
	# The post request, if any.

	my $cookie = EPrints::Apache::AnApache::cookie( 
		$request,
		"eprints_lang" );
	push @prefs, $cookie if defined $cookie;

	# then look at the accept language header
	my $accept_language = EPrints::Apache::AnApache::header_in( 
				$request,
				"Accept-Language" );

	if( defined $accept_language )
	{
		# Middle choice is exact browser setting
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/;.*$//;
			push @prefs, $browser_lang;
		}
	
		# Next choice is general browser setting (so fr-ca matches
		#	'fr' rather than default to 'en')
		foreach my $browser_lang ( split( /, */, $accept_language ) )
		{
			$browser_lang =~ s/-.*$//;
			push @prefs, $browser_lang;
		}
	}
		
	# last choice is always...	
	push @prefs, $repository->get_conf( "defaultlanguage" );

	# So, which one to use....
	my $arc_langs = $repository->get_conf( "languages" );	
	foreach my $pref_lang ( @prefs )
	{
		foreach my $langid ( @{$arc_langs} )
		{
			if( $pref_lang eq $langid )
			{
				# it's a real language id, go with it!
				return $pref_lang;
			}
		}
	}

	print STDERR <<END;
Something odd happend in the language selection code... 
Did you make a default language which is not in the list of languages?
END
	return undef;
}

######################################################################
=pod

=item $handle->change_lang( $newlangid )

Change the current language of the handle. $newlangid should be a
valid country code for the current repository.

An invalid code will cause eprints to terminate with an error.

e.g $handle->change_lang( "de" ) # sets the language to German

=cut
######################################################################

sub change_lang
{
	my( $self, $newlangid ) = @_;

	if( !defined $newlangid )
	{
		$newlangid = $self->{repository}->get_conf( "defaultlanguage" );
	}
	$self->{lang} = $self->{repository}->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
}


######################################################################
=pod

=item $xhtml_phrase = $handle->html_phrase( $phraseid, %inserts )

Return an XHTML DOM object describing a phrase from the phrase files.

$phraseid is the id of the phrase to return. If the same ID appears
in both the repository-specific phrases file and the system phrases file
then the repository-specific one is used.

If the phrase contains <ep:pin> elements, then each one should have
an entry in %inserts where the key is the "ref" of the pin and the
value is an XHTML DOM object describing what the pin should be 
replaced with.

Return a DOM object containing the archivename phrase for the current repository.
  $name_dom = $handle->html_phrase("archivename"); 

Returns a DOM object containing the error message inserting the name of a field
  $error_dom = $handle->html_phrase("validate:bad_email", 
      fieldname => $email_field->render_name($handle)
  );

=cut
######################################################################

sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
        
	$self->{used_phrases}->{$phraseid} = 1;

	my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );
	
	return $r;
}


######################################################################
=pod

=item $utf8_text = $handle->phrase( $phraseid, %inserts )

Performs the same function as html_phrase, but returns plain text.

All HTML elements will be removed, <br> and <p> will be converted 
into breaks in the text. <img> tags will be replaced with their 
"alt" values.

Return a string containing the text of the phrase 
  $name_text = $handle->phrase("archivename"); 
  

=cut
######################################################################

sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	$self->{used_phrases}->{$phraseid} = 1;
	foreach( keys %inserts )
	{
		$inserts{$_} = $self->make_text( $inserts{$_} );
	}
        my $r = $self->{lang}->phrase( $phraseid, \%inserts , $self);
	my $string =  EPrints::Utils::tree_to_utf8( $r, 40 );
	EPrints::XML::dispose( $r );
	return $string;
}

######################################################################

#=item $language = $handle->get_lang

#Return the EPrints::Language object for this handle current language.

######################################################################

sub get_lang
{
	my( $self ) = @_;

	return $self->{lang};
}


######################################################################
=pod

=item $langid = $handle->get_langid

Return the ISO ID code of the current language of this handle. e.g. "en" for english.

=cut
######################################################################

sub get_langid
{
	my( $self ) = @_;

	return $self->{lang}->get_id();
}



#cjg: should be a util? or even a property of repository?

######################################################################
=pod

=item $value = EPrints::RepositoryHandle::best_language( $repository, $lang, %values )

$repository is the current repository. $lang is the prefered language.

%values contains keys which are language ids, and values which is
text or phrases in those languages, all translations of the same 
thing.

This function returns one of the values from %values based on the 
following logic:

If possible, return the value for $lang.

Otherwise, if possible return the value for the default language of
this repository.

Otherwise, if possible return the value for "en" (English).

Otherwise just return any one value.

This means that the viewer sees the best possible phrase. 

=cut
######################################################################

sub best_language
{
	my( $repository, $lang, %values ) = @_;

	# no options?
	return undef if( scalar keys %values == 0 );

	# The language of the current handle is best
	return $values{$lang} if( defined $lang && defined $values{$lang} );

	# The default language of the repository is second best	
	my $defaultlangid = $repository->get_conf( "defaultlanguage" );
	return $values{$defaultlangid} if( defined $values{$defaultlangid} );

	# Bit of personal bias: We'll try English before we just
	# pick the first of the heap.
	return $values{en} if( defined $values{en} );

	# Anything is better than nothing.
	my $akey = (keys %values)[0];
	return $values{$akey};
}




######################################################################
# $viewname = $handle->get_view_name( $dataset, $viewid )
#
# Return a UTF8 encoded string containing the human readable name
# of the /view/ section with the ID $viewid.
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}

######################################################################
######################################################################
# Page Methods
######################################################################
######################################################################
=pod

=back

=head1 Page Methods

=cut
######################################################################



######################################################################
# $handle->write_static_page( $filebase, $parts, [$page_id], [$wrote_files] )
#
# Write an .html file plus a set of files describing the parts of the
# page for use with the dynamic template option.
#
# $filebase - is the name of the page without the .html suffix.
#
# $parts - a reference to a hash containing DOM trees.
#
# $page_id - the id attribute the body tag for this page will have (for style and javascript purposes) 
#
# $wrote_files - any filenames written are logged in it as keys.
######################################################################

sub write_static_page
{
	my( $self, $filebase, $parts, $page_id, $wrote_files ) = @_;

	print "Writing: $filebase\n" if( $self->{noise} > 1 );
	
	my $dir = $filebase;
	$dir =~ s/\/[^\/]*$//;

	if( !-d $dir ) { EPrints::Platform::mkdir( $dir ); }
	if( !defined $parts->{template} && -e "$filebase.template" )
	{
		unlink( "$filebase.template" );
	}
	foreach my $part_id ( keys %{$parts} )
	{
		my $file = $filebase.".".$part_id;
		if( open( CACHE, ">$file" ) )
		{
			binmode(CACHE,":utf8");
			print CACHE EPrints::XML::to_string( $parts->{$part_id}, undef, 1 );
			close CACHE;
			if( defined $wrote_files )
			{
				$wrote_files->{$file} = 1;
			}
		}
		else
		{
			$self->{repository}->log( "Could not write to file $file" );
		}
	}


	my $title_textonly_file = $filebase.".title.textonly";
	if( open( CACHE, ">$title_textonly_file" ) )
	{
		binmode(CACHE,":utf8");
		print CACHE EPrints::Utils::tree_to_utf8( $parts->{title}, undef, undef, undef, 1 ); # don't convert href's to <http://...>'s
		close CACHE;
		if( defined $wrote_files )
		{
			$wrote_files->{$title_textonly_file} = 1;
		}
	}
	else
	{
		$self->{repository}->log( "Could not write to file $title_textonly_file" );
	}

	my $html_file = $filebase.".html";
	$self->prepare_page( $parts, page_id=>$page_id );
	$self->page_to_file( $html_file, $wrote_files );
}

######################################################################
=pod

=over 4

=item $handle->prepare_page( $parts, %options )

Create an XHTML page for this handle. 

This function only builds the page it does not output it any way, see
the send_page method for that.

If template is set then an alternate template file is used.

$parts is a hash containing the following.

$parts->{title} - title for this page
$parts->{page} - the page content of this page

Options include:

page_id=>"id_to_put_in_body_tag" i.e. <body id="id_to_put_in_body_tag">
template=>"my_template" the name of the template to use.

=cut
######################################################################

sub prepare_page
{
	my( $self, $map, %options ) = @_;

	unless( $self->{offline} || !defined $self->{query} )
	{
		my $mo = $self->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			$self->{page} = $map->{page};
			return;
		}

		my $dp = $self->param( "edit_phrases" );
		# phrase debugging code.

		if( defined $dp && $dp eq "yes" )
		{
			my $current_user = $self->current_user;	
			if( defined $current_user && $current_user->allow( "config/edit/phrase" ) )
			{
				my $phrase_screen = $self->plugin( "Screen::Admin::Phrases",
		  			phrase_ids => [ sort keys %{$self->{used_phrases}} ] );
				$map->{page} = $self->make_doc_fragment;
				my $url = $self->get_full_url;
				my( $a, $b ) = split( /\?/, $url );
				my @parts = ();
				foreach my $part ( split( "&", $b ) )	
				{
					next if( $part =~ m/^edit(_|\%5F)phrases=yes$/ );
					push @parts, $part;
				}
				$url = $a."?".join( "&", @parts );
				my $div = $self->make_element( "div", style=>"margin-bottom: 1em" );
				$map->{page}->appendChild( $div );
				$div->appendChild( $self->html_phrase( "lib/session:phrase_edit_back",
					link => $self->render_link( $url ),
					page_title => $self->clone_for_me( $map->{title},1 ) ) );
				$map->{page}->appendChild( $phrase_screen->render );
				$map->{title} = $self->html_phrase( "lib/session:phrase_edit_title",
					page_title => $map->{title} );
			}
		}
	}
	
	if( $self->get_repository->get_conf( "dynamic_template","enable" ) )
	{
		if( $self->get_repository->can_call( "dynamic_template", "function" ) )
		{
			$self->get_repository->call( [ "dynamic_template", "function" ],
				$self,
				$map );
		}
	}

	my $pagehooks = $self->get_repository->get_conf( "pagehooks" );
	$pagehooks = {} if !defined $pagehooks;
	my $ph = $pagehooks->{$options{page_id}} if defined $options{page_id};
	$ph = {} if !defined $ph;
	if( defined $options{page_id} )
	{
		$ph->{bodyattr}->{id} = "page_".$options{page_id};
	}

	# only really useful for head & pagetop, but it might as
	# well support the others

	foreach( keys %{$map} )
	{
		next if( !defined $ph->{$_} );

		my $pt = $self->make_doc_fragment;
		$pt->appendChild( $map->{$_} );
		my $ptnew = $self->clone_for_me(
			$ph->{$_},
			1 );
		$pt->appendChild( $ptnew );
		$map->{$_} = $pt;
	}

	if( !defined $options{template} )
	{
		if( $self->get_secure )
		{
			$options{template} = "secure";
		}
		else
		{
			$options{template} = "default";
		}
	}

	my $parts = $self->get_repository->get_template_parts( 
				$self->get_langid, 
				$options{template} );
	my @output = ();
	my $is_html = 0;

	foreach my $bit ( @{$parts} )
	{
		$is_html = !$is_html;

		if( $is_html )
		{
			push @output, $bit;
			next;
		}

		# either 
		#  print:epscript-expr
		#  pin:id-of-a-pin
		#  pin:id-of-a-pin.textonly
		#  phrase:id-of-a-phrase
		my( @parts ) = split( ":", $bit );
		my $type = shift @parts;

		if( $type eq "print" )
		{
			my $expr = join "", @parts;
			my $result = EPrints::XML::to_string( EPrints::Script::print( $expr, { handle =>$self } ), undef, 1 );
			push @output, $result;
			next;
		}

		if( $type eq "phrase" )
		{	
			my $phraseid = join "", @parts;
			push @output, EPrints::XML::to_string( $self->html_phrase( $phraseid ), undef, 1 );
			next;
		}

		if( $type eq "pin" )
		{	
			my $pinid = shift @parts;
			my $modifier = shift @parts;
			if( defined $modifier && $modifier eq "textonly" )
			{
				my $text;
				if( defined $map->{"utf-8.".$pinid.".textonly"} )
				{
					$text = $map->{"utf-8.".$pinid.".textonly"};
				}
				elsif( defined $map->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					$text = EPrints::Utils::tree_to_utf8( $map->{$pinid}, undef, undef, undef, 1 ); 
				}

				# else no title
				next unless defined $text;

				# escape any entities in the text (<>&" etc.)
				my $xml = $self->make_text( $text );
				push @output, EPrints::XML::to_string( $xml, undef, 1 );
				EPrints::XML::dispose( $xml );
				next;
			}
	
			if( defined $map->{"utf-8.".$pinid} )
			{
				push @output, $map->{"utf-8.".$pinid};
			}
			elsif( defined $map->{$pinid} )
			{
#EPrints::XML::tidy( $map->{$pinid} );
				push @output, EPrints::XML::to_string( $map->{$pinid}, undef, 1 );
			}
		}

		# otherwise this element is missing. Leave it blank.
	
	}
	$self->{text_page} = join( "", @output );

	return;
}


######################################################################
=pod

=item $handle->send_page( %httpopts )

Send a web page out by HTTP. Only relevant if this is a CGI script.
prepare_page must have been called first.

$httpopts->{content_type} - Default value is "text/html; charset=UTF-8". This sets
the http content type header.

$httpopts->{lang} - If this is set then a cookie setting the language preference
is set in the http header.

Dispose of the XML once it's sent out.

=cut
######################################################################

sub send_page
{
	my( $self, %httpopts ) = @_;
	$self->send_http_header( %httpopts );
	print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
	if( defined $self->{text_page} )
	{
		binmode(STDOUT,":utf8");
		print $self->{text_page};
	}
	else
	{
		binmode(STDOUT,":utf8");
		print EPrints::XML::to_string( $self->{page}, undef, 1 );
		EPrints::XML::dispose( $self->{page} );
		delete $self->{page};
	}
	delete $self->{text_page};
}


######################################################################
#=pod

#=item $handle->page_to_file( $filename, [$wrote_files] )

#Write out the current webpage to the given filename.

#build_page must have been called first.

#Dispose of the XML once it's sent out.

#If $wrote_files is set then keys are created in it for each file
#created.

#=cut
######################################################################

sub page_to_file
{
	my( $self , $filename, $wrote_files ) = @_;
	
	if( defined $self->{text_page} )
	{
		unless( open( XMLFILE, ">$filename" ) )
		{
			EPrints::abort( <<END );
Can't open to write to XML file: $filename
END
		}
		if( defined $wrote_files )
		{
			$wrote_files->{$filename} = 1;
		}
		binmode(XMLFILE,":utf8");
		print XMLFILE $self->{text_page};
		close XMLFILE;
	}
	else
	{
		EPrints::XML::write_xhtml_file( $self->{page}, $filename );
		if( defined $wrote_files )
		{
			$wrote_files->{$filename} = 1;
		}
		EPrints::XML::dispose( $self->{page} );
	}
	delete $self->{page};
	delete $self->{text_page};
}


######################################################################
#=pod

#=item $handle->set_page( $newhtml )

#Erase the current page for this session, if any, and replace it with
#the XML DOM structure described by $newhtml.

#This page is what is output by page_to_file or send_page.

#$newhtml is a normal DOM Element, not a document object.

#=cut
######################################################################

sub set_page
{
	my( $self, $newhtml ) = @_;
	
	if( defined $self->{page} )
	{
		EPrints::XML::dispose( $self->{page} );
	}
	$self->{page} = $newhtml;
}

1;

######################################################################
=pod

=back

=cut

######################################################################



1;


