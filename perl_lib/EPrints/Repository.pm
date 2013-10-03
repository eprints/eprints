######################################################################
#
# EPrints::Repository
#
######################################################################
#
#
######################################################################


=pod

=for Pod2Wiki

=head1 NAME

B<EPrints::Repository> - Single connection to a specific EPrints Repository

=head1 DESCRIPTION

This module is really a Repository, REALLY. The name is up to date 
and everything :-) 

EPrints::Repository represents a connection to the EPrints system. It
connects to a single EPrints repository, and the database used by
that repository.

Each Repository has a "current language". If you are running in a 
multilingual mode, this is used by the HTML rendering functions to
choose what language to return text in.

The Repository object also knows about the current apache connection,
if there is one, including the CGI parameters. 

If the connection requires a username and password then it can also 
give access to the L<EPrints::DataObj::User> object representing the user who is
causing this request. See current_user().

The Repository object also provides access to the L<EPrints::XHTML> class which contains
many methods for creating XHTML results which can be returned via the web 
interface. 

=head1 METHODS

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{database}
#     A EPrints::Database object representing the connection
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
#  $self->{page}
#     Used to store the output XHTML page between "build_page" and
#     "send_page"
#
#  $self->{lang}
#     The current language that this session should use. eg. "en" or "fr"
#     It is used to determine which phrases and template will be used.
#
######################################################################

package EPrints::Repository;

use EPrints;
use EPrints::Const qw( :trigger );

#use URI::Escape;
use CGI qw(-compile);
use Cache::Memcached::Fast;

use strict;

my $USE_MEMCACHED = 0;

######################################################################
=pod

=item $repository = EPrints::Repository->new( %opts )

Creates and returns a new repository object. This is a utility object only and
will only have the basic system configuration available.

=item $repository = EPrints::Repository->new( $repository_id, %opts )

Create a connection to an EPrints repository $repository_id which provides
access to the database and to the repository configuration.

Options:

	db_connect - 1
	check_db - 1
	noise - 0

=cut
######################################################################

# opts:
#  consume_post (default 1), assumes cgi=1
#  cgi (default 0)
#  noise (default 0)
#  db_connect (default 1)
#  check_db (default 1)
#
sub new
{
	my $class = shift;

	if( @_ % 2 == 0 )
	{
		return $class->_new( @_ );
	}

	my( $repository_id, %opts ) = @_;

	EPrints::Utils::process_parameters( \%opts, {
		  consume_post => 1,
		           cgi => 0,
		         noise => 0,
		    db_connect => 1,
		      check_db => 1,
	});

	my $self = bless {}, $class;

	$self->{noise} = $opts{noise};
	$self->{noise} = 0 if ( !defined $self->{noise} );

	$self->{used_phrases} = {};

	$self->{offline} = 1;
	if( $opts{cgi} )
	{
		EPrints->abort( __PACKAGE__."::new() called with cgi argument" );
	}

	$self->{id} = $repository_id;

	$self->load_config();

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Repository.\n"; }

	if( $self->{offline} )
	{
		# Set a script to use the default language unless it 
		# overrides it
		$self->change_lang( 
			$self->get_conf( "defaultlanguage" ) );
	}
	else
	{
		# running as CGI, Lets work out what language the
		# client wants...
		$self->change_lang( get_session_language( 
			$self,
			$self->{request} ) );
	}
	
	if( defined $opts{db_connect} && $opts{db_connect} == 0 )
	{
		$opts{check_db} = 0;
	}
	else
	{
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
	}

	#cjg make this a method of EPrints::Database?
	if( !defined $opts{check_db} || $opts{check_db} )
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

	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	if( !$self->{offline} && (!defined $opts{consume_post} || $opts{consume_post}) )
	{
		$self->read_params; 
	}

	$self->init_cache;

	$self->call( "session_init", $self, $self->{offline} );

	$self->{loadtime} = time();
	
	return( $self );
}

sub _new
{
	my( $class, %opts ) = @_;

	my $self = bless {}, $class;

	$self->{offline} = 1;

	$self->{config} = EPrints::Config::system_config();
	$self->{config}->{field_defaults} = {}
		if !defined $self->{config}->{field_defaults};

	$self->{config}->{defaultlanguage} = 'en';
	$self->{config}->{languages} = [qw( en )];

	$self->_load_datasets or EPrints->abort( "Failed to load datasets" );
	$self->_load_languages or EPrints->abort( "Failed to load languages" );
	$self->_load_storage or EPrints->abort( "Failed to load storage" );
	$self->_load_plugins or EPrints->abort( "Failed to load plugins" );

	$self->change_lang( $self->config( "defaultlanguage" ) );

	$self->{loadtime} = time();

	return $self;
}


sub init_cache
{
	my( $self ) = @_;

	return if( !$USE_MEMCACHED );

	if( defined $self->{memd} )
	{
		return;
	}

	my $memd = new Cache::Memcached::Fast({
		servers => [
			   'localhost:11211'
		],
		namespace => 'my:',
		connect_timeout => 0.2,
		io_timeout => 0.5,
		close_on_error => 1,
		compress_threshold => 100_000,
		compress_ratio => 0.9,
		compress_methods => [ \&IO::Compress::Gzip::gzip,
				    \&IO::Uncompress::Gunzip::gunzip ],
		max_failures => 3,
		failure_timeout => 2,
		ketama_points => 150,
		nowait => 1,
		hash_namespace => 1,
		serialize_methods => [ \&Storable::freeze, \&Storable::thaw ],
		utf8 => ($^V ge v5.8.1 ? 1 : 0),
		max_size => 512 * 1024,
	});

	if( defined $memd && ref( $memd ) ne '' )
	{
		$self->{memd} = $memd;
	}

	print STDERR "init_cache\n";
}

sub cache_get
{
	my( $self, $key ) = @_;

	if( !defined $self->{memd} )
	{
		return undef;
	}

#	print STDERR "cache_get: '".$self->id.":$key\n";

	return $self->{memd}->get( $self->id.":$key" );
}

sub cache_set
{
	my( $self, $key, $value ) = @_;

	if( !defined $self->{memd} )
	{
		return undef;
	}
	
#	print STDERR "cache_set: '".$self->id.":$key - storing a $value\n";

	return eval { $self->{memd}->set( $self->id.":$key", $value ) };
}

sub cache_remove
{
	my( $self, $key ) = @_;

	if( !defined $self->{memd} )
	{
		return undef;
	}

#	print STDERR "cache_remove: '".$self->id.":$key\n";

	return $self->{memd}->delete( $self->id.":$key" );
}

# same as cache_set but doesn't set the value if it doesn't exist
sub cache_replace
{
	my( $self, $key, $value ) = @_;

	if( !defined $self->{memd} )
	{
		return undef;
	}
	
#	print STDERR "cache_replace: '".$self->id.":$key - storing a $value\n";

	return $self->{memd}->replace( $self->id.":$key", $value );
}

=begin InternalDoc

=item $repo->init_from_thread()

Do whatever needs to be done to reinstate the repository after a new thread is spawned.

This is called during the CLONE() stage.

=end InternalDoc

=cut

sub init_from_thread
{
	my( $self ) = @_;

	# force recreation of XML object
	delete $self->{xml};

	# force reload
#	$self->{loadtime} = 0;

	$self->_load_workflows();
	$self->_load_languages();
	$self->_load_templates();
	$self->_load_citation_specs();
	$self->_load_storage();
	$self->init_cache;
}

# add the relative paths + http_* config if not set already by cfg.d
sub _add_live_http_paths
{
	my( $self ) = @_;

	my $config = $self->{config};

	$config->{"rel_path"} = $self->get_url(
		path => "static",
	);
	$config->{"rel_cgipath"} = $self->get_url(
		path => "cgi",
	);
}

######################################################################
=pod

=begin InternalDoc

=item $request = $repository->request;

Return the Apache request object (from mod_perl) or undefined if 
this isn't a CGI script.

=end InternalDoc

=cut
######################################################################

sub get_request { &request }
sub request
{
	my( $self ) = @_;

	return $self->{request};
}

######################################################################
=pod

=over 4

=item $query = $repository->query

Return the L<CGI> object describing the current HTTP query, or 
undefined if this isn't a CGI script.

=cut
######################################################################

sub get_query { &query }
sub query
{
	my( $self ) = @_;

	return undef if $self->{offline};

	if( !defined $self->{query} )
	{
		$self->read_params;
	}

	return $self->{query};
}

######################################################################
=pod

=item $value or @values = $repository->param( $name )

Passes through to CGI.pm param method.

$value = $repository->param( $name ): returns the value of CGI parameter
$name.

$value = $repository->param( $name ): returns the value of CGI parameter
$name.

@values = $repository->param: returns an array of the names of all the
CGI parameters in the current request.

=cut
######################################################################

sub param
{
	my( $self, $name ) = @_;

	if( !defined $self->{query} ) 
	{
		$self->read_params;
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


######################################################################
=pod

=begin InternalDoc

=item $repository->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

=end InternalDoc

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	$self->call( "session_close", $self );

	if( $self->{noise} >= 2 ) { print "Ending EPrints Repository.\n\n"; }

	# if we're online then clean-up happens later
	return if !$self->{offline};

	$self->{database}->disconnect();

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}



sub load_config
{
	my( $self, $load_xml ) = @_;

	$load_xml = 1 if !defined $load_xml;

	$self->{config} = EPrints::Config::load_repository_config_module( $self->{id} );

	# add defaults
	if( !defined $self->{config}->{variables_path} )
	{
		$self->{config}->{variables_path} = $self->config( 'archiveroot' )."/var";
	}

	unless( defined $self->{config} )
	{
		print STDERR "Could not load repository config perl files for $self->{id}\n";
		return;
	}

	$self->{class} = "EPrints::Config::".$self->{id};

	$self->_add_http_paths;

	# re-add live paths
	$self->_add_live_http_paths;

	# If loading any of the XML config files then 
	# abort loading the config for this repository.
	if( $load_xml )
	{
		# $self->generate_dtd() || return;
		$self->_load_workflows() || return;
		$self->_load_namedsets() || return;
		$self->_load_datasets() || return;
		$self->_load_languages() || return;
		$self->_load_templates() || return;
		$self->_load_citation_specs() || return;
		$self->_load_storage() || return;
	}

	$self->_load_plugins() || return;

	$self->{field_defaults} = {};

	return $self;
}

######################################################################
=pod

=item $xml = $repo->xml

Return an L<EPrints::XML> object for working with XML.

=cut
######################################################################

sub xml($)
{
	my( $self ) = @_;

	return $self->{xml} if defined $self->{xml};

	return $self->{xml} = EPrints::XML->new( $self );
}

######################################################################
=pod

=item $xhtml = $repo->xhtml

Return an L<EPrints::XHTML> object for working with XHTML.

=cut
######################################################################

sub xhtml($) 
{
	my( $self ) = @_;

	return $self->{xhtml} if defined $self->{xhtml};

	return $self->{xhtml} = EPrints::XHTML->new( $self );
}

######################################################################
=pod

=item $eprint = $repository->eprint( $eprint_id );

A convience method to return the L<EPrints::DataObj::EPrint> with 
the given ID, or undef.

Equivent to $repository->dataset("eprint")->dataobj( $eprint_id )

=cut
######################################################################

sub eprint($$)
{
	my( $repository, $eprint_id ) = @_;

	return $repository->dataset( "eprint" )->get_object( $repository, $eprint_id );
}

######################################################################
=pod

=item $user = $repository->current_user

Return the current logged in L<EPrints::DataObj::User> for this session.

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

		# custom auth
		if( $self->get_repository->can_call( 'get_current_user' ) )
		{
			$self->{current_user} = $self->get_repository->call( 'get_current_user', $self );
		}
		# cookie auth
		if( !defined $self->{current_user} )
		{
			$self->{current_user} = $self->_current_user_auth_cookie;
		}
		# basic auth
		if( !defined $self->{current_user} )
		{
			$self->{current_user} = $self->_current_user_auth_basic;
		}
		$self->{already_in_current_user} = 0;
	}
	return $self->{current_user};
}
	
######################################################################
=pod

=item $user = $repository->user( $user_id );

A convience method to return the L<EPrints::DataObj::User> with 
the given ID, or undef.

Equivent to $repository->dataset("user")->dataobj( $user_id )

=cut
######################################################################

sub user($$)
{
	my( $repository, $user_id ) = @_;

	return $repository->dataset( "user" )->get_object( $repository, $user_id );
}
	
######################################################################
=pod

=item $user = $repository->user_by_username( $username );

Return the user with the given username, or undef.

=cut
######################################################################

sub user_by_username($$)
{
	my( $repository, $username ) = @_;

	return EPrints::DataObj::User::user_with_username( $repository, $username )
}
	
######################################################################
=pod

=item $user = $repository->user_by_email( $email );

Return the L<EPrints::DataObj::User> with the given email, or undef.

=cut
######################################################################

sub user_by_email($$)
{
	my( $repository, $email ) = @_;

	return EPrints::DataObj::User::user_with_email( $repository, $email )
}

sub _add_http_paths
{
	my( $self ) = @_;

	my $config = $self->{config};

	if( $config->{securehost} )
	{
		$config->{secureport} ||= 443;
	}

	# Backwards-compatibility: http is fairly simple, https may go wrong
	if( !defined($config->{"http_root"}) )
	{
		my $u = URI->new( $config->{"base_url"} );
		$config->{"http_root"} = $u->path;
		$u = URI->new( $config->{"perl_url"} );
		$config->{"http_cgiroot"} = $u->path;
	}

	$config->{"http_cgiroot"} ||= $config->{"http_root"}."/cgi";

	if( $config->{"securehost"} )
	{
		$config->{"https_root"} = $config->{"securepath"}
			if !defined($config->{"https_root"});
		$config->{"https_root"} = $config->{"http_root"}
			if !defined($config->{"https_root"});
		$config->{"https_cgiroot"} = $config->{"http_cgiroot"}
			if !defined($config->{"https_cgiroot"});
	}

	$config->{"http_url"} ||= $self->get_url(
		scheme => ($config->{host} ? "http" : "https"),
		host => 1,
		path => "static",
	);
	$config->{"http_cgiurl"} ||= $self->get_url(
		scheme => ($config->{host} ? "http" : "https"),
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

	# old-style configuration names
	$config->{"urlpath"} ||= $config->{"http_root"};
	$config->{"base_url"} ||= $config->{"http_url"} . "/";
	$config->{"perl_url"} ||= $config->{"http_cgiurl"};
	$config->{"frontpage"} ||= $config->{"http_url"} . "/";
	$config->{"userhome"} ||= $config->{"http_cgiroot"} . "/users/home";
}
 
######################################################################
=pod

=begin InternalDoc

=item $success = $repository_config->_load_workflows

 Attempts to load and cache the workflows for this repository

=end InternalDoc

=cut
######################################################################

sub _load_workflows
{
	my( $self ) = @_;

	$self->{workflows} = {};

	# load system-level workflows
	EPrints::Workflow::load_all( 
		$self->config( "lib_path" )."/workflows",
		$self->{workflows} );

	if( -e $self->config( "base_path" )."/site_lib/workflows" )
	{	
		# load /site_lib/ workflows
		EPrints::Workflow::load_all( 
			$self->config( "base_path" )."/site_lib/workflows",
			$self->{workflows} );
	}

	# load repository-specific workflows (may overwrite)
	EPrints::Workflow::load_all( 
		$self->config( "config_path" )."/workflows",
		$self->{workflows} );

	return 1;
}

=begin InternalDoc

=item $repo->_load_storage()

Loads the storage layer which includes a XML workflow for storing items.

=end InternalDoc

=cut

sub _load_storage
{
	my( $self ) = @_;

	$self->{storage} = EPrints::Storage->new( $self );

	return defined $self->{storage};
}

######################################################################
# 
# $workflow_xml = $repository->get_workflow_config( $datasetid, $workflowid )
#
# Return the XML of the requested workflow
#
######################################################################

sub get_workflow_config
{
	my( $self, $datasetid, $workflowid ) = @_;

	my $r = EPrints::Workflow::get_workflow_config( 
		$workflowid,
		$self->{workflows}->{$datasetid} );

	return $r;
}

######################################################################
# 
# $success = $repository_config->_load_languages
#
# Attempts to load and cache all the phrase files for this repository.
#
######################################################################

sub _load_languages
{
	my( $self ) = @_;
	
	my $defaultid = $self->config( "defaultlanguage" );
	$self->{langs}->{$defaultid} = EPrints::Language->new( 
		$defaultid, 
		$self );

	if( !defined $self->{langs}->{$defaultid} )
	{
		return 0;
	}

	my $langid;
	foreach $langid ( @{$self->config( "languages" )} )
	{
		next if( $langid eq $defaultid );	
		$self->{langs}->{$langid} =
			 EPrints::Language->new( 
				$langid , 
				$self , 
				$self->{langs}->{$defaultid} );
		if( !defined $self->{langs}->{$langid} )
		{
			return 0;
		}
	}
	return 1;
}


######################################################################
=pod

=begin InternalDoc

=item $language = $repository->get_language( [$langid] )

Returns the EPrints::Language for the requested language id (or the
default for this repository if $langid is not specified). 

=end InternalDoc

=cut
######################################################################

sub get_language
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->config( "defaultlanguage" );
	}
	return $self->{langs}->{$langid};
}

######################################################################
# 
# $success = $repository_config->_load_citation_specs
#
# Attempts to load and cache all the citation styles for this repository.
#
######################################################################

sub _load_citation_specs
{
	my( $self ) = @_;

	$self->{citations} = {};



	# load repository-specific citations
	$self->_load_citation_dir( $self->config( "config_path" )."/citations" );
	# load system-level citations (won't overwrite)
	$self->_load_citation_dir( $self->config( "lib_path" )."/citations" );

	if( -e $self->config( "base_path" )."/site_lib/citations" )
	{
		$self->_load_citation_dir( $self->config( "base_path" )."/site_lib/citations" );
	}

	return 1;
}

sub _load_citation_dir
{
	my( $self, $dir ) = @_;

	my $dh;
	opendir( $dh, $dir );
	my @dirs = ();
	while( my $fn = readdir( $dh ) )
	{
		next if $fn =~ m/^\./;
		push @dirs,$fn if( -d "$dir/$fn" );
	}
	closedir $dh;

	# for each dataset dir
	foreach my $dsid ( @dirs )
	{
		next if !exists $self->{datasets}->{$dsid};
		opendir( $dh, "$dir/$dsid" );
		while( my $fn = readdir( $dh ) )
		{
			next if $fn =~ m/^\./;
			my $fileid = substr($fn,0,-4);
			# prefer .xsl to .xml
			next if $fn =~ /\.xml$/
				&& $EPrints::XSLT &&
				-e "$dir/$dsid/$fileid.xsl";
			$self->_load_citation_file( 
				"$dir/$dsid/$fn",
				$dsid,
				$fileid
			);
		}
		closedir $dh;
	}

	return 1;
}

sub _load_citation_file
{
	my( $self, $file, $dsid, $fileid ) = @_;

	return if defined $self->{citations}->{$dsid}->{$fileid};

	if( !-e $file )
	{
		if( $fileid eq "default" )
		{
			EPrints::abort( "Default citation file for '$dsid' does not exist. Was expecting a file at '$file'." );
		}
		$self->log( "Citation file '$fileid' for '$dsid' does not exist. Was expecting a file at '$file'." );
		return;
	}

	if( $file =~ /\.xml$/ )
	{
		$self->{citations}->{$dsid}->{$fileid} = EPrints::Citation::EPC->new(
			$file,
			dataset => $self->dataset( $dsid )
		);
	}

	if( $file =~ /\.xsl$/ && $EPrints::XSLT )
	{
		$self->{citations}->{$dsid}->{$fileid} = EPrints::Citation::XSL->new(
			$file,
			dataset => $self->dataset( $dsid )
		);
	}
}


######################################################################
# 
# $success = $repository_config->_load_templates
#
# Loads and caches all the html template files for this repository.
#
######################################################################

sub _load_templates
{
	my( $self ) = @_;

	$self->{html_templates} = {};
	$self->{text_templates} = {};
	$self->{template_mtime} = {};
	$self->{template_path} = {};

	foreach my $langid ( @{$self->config( "languages" )} )
	{
		foreach my $dir ($self->template_dirs( $langid ))
		{
			opendir( my $dh, $dir ) or next;
			while( my $fn = readdir( $dh ) )
			{
				next if $fn =~ m/^\./;
				next if $fn !~ /\.xml$/;
				my $id = $fn;
				$id =~ s/\.xml$//;
				next if
					exists $self->{template_mtime}->{$id} &&
					exists $self->{template_mtime}->{$id}->{$langid};
				$self->{template_path}->{$id}->{$langid} = "$dir/$fn";
				$self->freshen_template( $langid, $id );
			}
			closedir( $dh );
		}

		if( !defined $self->{html_templates}->{default}->{$langid} )
		{
			EPrints::abort( "Failed to load default template for language $langid" );
		}
	}

	return 1;
}

sub freshen_template
{
	my( $self, $langid, $id ) = @_;

	my $curr_lang = $self->{lang};
	$self->change_lang( $langid );

	my $path = $self->{template_path}->{$id}->{$langid};

	my @filestat = stat( $path );
	my $mtime = $filestat[9];

	my $old_mtime = $self->{template_mtime}->{$id}->{$langid};
	if( defined $old_mtime && $old_mtime == $mtime )
	{
		$self->{lang} = $curr_lang;
		return;
	}

	my $template = $self->_load_template( $path );
	if( !defined $template ) 
	{ 
		$self->{lang} = $curr_lang;
		return 0; 
	}

	$self->{html_templates}->{$id}->{$langid} = $template;
	$self->{text_templates}->{$id}->{$langid} = $self->_template_to_text( $template, $langid );
	$self->{template_mtime}->{$id}->{$langid} = $mtime;
}

sub _template_to_text
{
	my( $self, $template, $langid ) = @_;

	$template = $self->xml->clone( $template );

	my $divide = "61fbfe1a470b4799264feccbbeb7a5ef";

        my @pins = $template->getElementsByTagName("pin");
	foreach my $pin ( @pins )
	{
		#$template
		my $parent = $pin->getParentNode;
		my $textonly = $pin->getAttribute( "textonly" );
		my $ref = "pin:".$pin->getAttribute( "ref" );
		if( defined $textonly && $textonly eq "yes" )
		{
			$ref.=":textonly";
		}
		my $textnode = $self->xml->create_text_node( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $pin );
	}

        my @prints = $template->getElementsByTagName("print");
	foreach my $print ( @prints )
	{
		my $parent = $print->getParentNode;
		my $ref = "print:".$print->getAttribute( "expr" );
		my $textnode = $self->xml->create_text_node( $divide.$ref.$divide );
		$parent->replaceChild( $textnode, $print );
	}

        my @phrases = $template->getElementsByTagName("phrase");
	
	foreach my $phrase ( @phrases )
	{
		my $done_phrase = EPrints::XML::EPC::process( $phrase, session=>$self );

		my $parent = $phrase->getParentNode;
		$parent->replaceChild( $done_phrase, $phrase );
	}

	$self->_divide_attributes( $template, $divide );

	my @r = split( "$divide", $self->xhtml->to_xhtml( $template ) );

	return \@r;
}

sub _divide_attributes
{
	my( $self, $node, $divide ) = @_;

	return unless( $self->xml->is( $node, "Element" ) );

	foreach my $kid ( $node->childNodes )
	{
		$self->_divide_attributes( $kid, $divide );
	}
	
	my $attrs = $node->attributes;

	return unless defined $attrs;
	
	for( my $i = 0; $i < $attrs->length; ++$i )
	{
		my $attr = $attrs->item( $i );
		my $v = $attr->nodeValue;
		next unless( $v =~ m/\{/ );
		my $name = $attr->nodeName;
		my @r = EPrints::XML::EPC::split_script_attribute( $v, $name );
		my @r2 = ();
		for( my $i = 0; $i<scalar @r; ++$i )
		{
			if( $i % 2 == 0 )
			{
				push @r2, $r[$i];
			}
			else
			{
				push @r2, "print:".$r[$i];
			}
		}
		if( scalar @r % 2 == 0 )
		{
			push @r2, "";
		}
		
		my $newv = join( $divide, @r2 );
		$attr->setValue( $newv );
	}

	return;
}

sub _load_template
{
	my( $self, $file ) = @_;
	my $doc = $self->parse_xml( $file );
	if( !defined $doc ) { return undef; }
	my $html = ($doc->getElementsByTagName( "html" ))[0];
	my $rvalue;
	if( !defined $html )
	{
		print STDERR "Missing <html> tag in $file\n";
	}
	else
	{
		$rvalue = $self->xml->clone( $html );
	}
	$self->xml->dispose( $doc );
	return $rvalue;
}


######################################################################
=pod

=begin InternalDoc

=item $template = $repository->get_template_parts( $langid, [$template_id] )

Returns an array of utf-8 strings alternating between XML and the id
of a pin to replace. This is used for the faster template construction.

=end InternalDoc

=cut
######################################################################

sub get_template_parts
{
	my( $self, $langid, $tempid ) = @_;
  
	if( !defined $tempid ) { $tempid = 'default'; }
	$self->freshen_template( $langid, $tempid );
	my $t = $self->{text_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $tempid
END
	}

	return $t;
}
######################################################################
=pod

=begin InternalDoc

=item $template = $repository->get_template( $langid, [$template_id] )

Returns the DOM document which is the webpage template for the given
language. Do not modify the template without cloning it first.

=end InternalDoc

=cut
######################################################################

sub get_template
{
	my( $self, $langid, $tempid ) = @_;
  
	if( !defined $tempid ) { $tempid = 'default'; }
	$self->freshen_template( $langid, $tempid );
	my $t = $self->{html_templates}->{$tempid}->{$langid};
	if( !defined $t ) 
	{
		EPrints::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $tempid
END
	}

	return $t;
}

######################################################################
# 
# $success = $repository_config->_load_namedsets
#
# Loads and caches all the named set lists from the cfg/namedsets/ directory.
#
######################################################################

sub _load_namedsets
{
	my( $self ) = @_;

	my @paths = ( 
		$self->config( "base_path" )."/site_lib/namedsets",
		$self->config( "config_path" )."/namedsets",
	);

	# load /namedsets/* 

	foreach my $dir ( @paths )
	{
		next if !-e $dir;
		my $dh;
		opendir( $dh, $dir );
		my @type_files = ();
		while( my $fn = readdir( $dh ) )
		{
			next if $fn=~m/^\./;
			push @type_files, $fn;
		}
		closedir( $dh );

		foreach my $tfile ( @type_files )
		{
			my $file = $dir."/".$tfile;

			my $type_set = $tfile;	
			open( FILE, $file ) || EPrints::abort( "Could not read $file" );

			my @types = ();
			foreach my $line (<FILE>)
			{
				$line =~ s/\015?\012?$//s;
				$line =~ s/#.*$//;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				my @values = split(' ',$line);
				$line = $values[0];
				next if (!defined $line);
				push @types, $line;
			}
			close FILE;

			$self->{types}->{$type_set} = \@types;
		}

	}

	return 1;
}

######################################################################
=pod

=begin InternalDoc

=item @type_ids = $repository->get_types( $type_set )

Return an array of keys for the named set. Comes from 
/cfg/types/foo.xml

=end InternalDoc

=cut
######################################################################

sub get_types
{
	my( $self, $type_set ) = @_;

	if( !defined $self->{types}->{$type_set} )
	{
		$self->log( "Request for unknown named set: $type_set" );
		return ();
	}

	return @{$self->{types}->{$type_set}};
}

######################################################################
# 
# $success = $repository_config->_load_datasets
#
# Loads and caches all the EPrints::DataSet objects belonging to this
# repository.
#
######################################################################

sub _load_datasets
{
	my( $self ) = @_;

	$self->{datasets} = {};

	# system datasets
	my %info = %{EPrints::DataSet::get_system_dataset_info()};

	# repository-specific datasets
	my $repository_datasets = $self->config( "datasets" );
	foreach my $ds_id ( keys %{$repository_datasets||{}} )
	{
		my $dataset = $repository_datasets->{$ds_id};
		foreach my $key (keys %$dataset)
		{
			if( defined $dataset->{$key} )
			{
				$info{$ds_id}->{$key} = $dataset->{$key};
			}
			else
			{
				delete $info{$ds_id};
			}
		}
	}

	# sort the datasets so that derived datasets follow (and hence share
	# their fields)
	foreach my $ds_id (
		sort { defined $info{$a}->{confid} <=> defined $info{$b}->{confid} }
		keys %info
		)
	{
		$self->{datasets}->{$ds_id} = EPrints::DataSet->new(
			repository => $self,
			name => $ds_id,
			%{$info{$ds_id}}
			);
	}

	return 1;
}

######################################################################
=pod

=begin InternalDoc

=item @dataset_ids = $repository->get_dataset_ids()

Returns a list of dataset ids in this repository.

=end InternalDoc

=cut
######################################################################

sub get_dataset_ids
{
	my( $self ) = @_;

	return keys %{$self->{datasets}};
}

######################################################################
=pod

=begin InternalDoc

=item @dataset_ids = $repository->get_sql_dataset_ids()

Returns a list of dataset ids that have database tables.

=end InternalDoc

=cut
######################################################################

sub get_sql_dataset_ids
{
	my( $self ) = @_;

	my @dataset_ids = $self->get_dataset_ids();

	return grep { !$self->get_dataset( $_ )->is_virtual } @dataset_ids;
}

######################################################################
=pod

=begin InternalDoc

=item @counter_ids = $repository->get_sql_counter_ids()

Returns a list of counter ids generated by the database.

=end InternalDoc

=cut
######################################################################

sub get_sql_counter_ids
{
	my( $self ) = @_;

	my @counter_ids;

	foreach my $ds_id ($self->get_sql_dataset_ids)
	{
		my $dataset = $self->get_dataset( $ds_id );
		foreach my $field ($dataset->get_fields)
		{
			next unless $field->isa( "EPrints::MetaField::Counter" );
			my $c_id = $field->get_property( "sql_counter" );
			push @counter_ids, $c_id if defined $c_id;
		}
	}

	return @counter_ids;
}

######################################################################
=pod

=item $dataset = $repository->dataset( $setname )

Return a given L<EPrints::DataSet> or undef if it doesn't exist.

=cut
######################################################################

sub get_dataset { return dataset( @_ ); }
sub dataset($$)
{
	my( $self , $setname ) = @_;

	my $ds = $self->{datasets}->{$setname};
	if( !defined $ds )
	{
		$self->log( "Unknown dataset: ".$setname );
	}

	return $ds;
}


######################################################################
# 
# $success = $repository_config->_load_plugins
#
# Load any plugins distinct to this repository.
#
######################################################################

sub _load_plugins
{
	my( $self ) = @_;

	# if we're reloading we need to reset the system plugins
	if( defined $self->{plugins} )
	{
		$self->{plugins}->reset;
	}

	$self->{plugins} = EPrints::PluginFactory->new( $self );

	return defined $self->{plugins};
}

=begin InternalDoc

=item $plugins = $repository->get_plugin_factory()

Return the plugins factory object.

=end InternalDoc

=cut

sub get_plugin_factory
{
	my( $self ) = @_;

	return $self->{plugins};
}

######################################################################
# 
# $classname = $repository->get_plugin_class
#
# Returns the perl module for a plugin with this id, using global
# and repository-sepcific plugins.
#
######################################################################

sub get_plugin_class
{
	my( $self, $pluginid ) = @_;

	return $self->{plugins}->get_plugin_class( $pluginid );
}

######################################################################
=pod

=item $confitem = $repository->config( $key, [@subkeys] )

Returns a named configuration setting including those defined in archvies/<archive_id>/cfg/cfg.d/ 

$repository->config( "stuff", "en", "foo" )

is equivalent to 

$repository->config( "stuff" )->{en}->{foo} 

=cut
######################################################################

sub get_conf { return config( @_ ); }
sub config($$@)
{
	my( $self, $key, @subkeys ) = @_;

	my $val = $self->{config}->{$key};
	foreach( @subkeys )
	{
		return undef unless defined $val;
		$val = $val->{$_};
	} 

	return $val;
}

=begin InternalDoc

=item $repository->run_trigger( TRIGGER_ID, %params )

Run all the triggers with the given TRIGGER_ID. Any return values are
set in the properties passed in in %params

=end InternalDoc

=cut

sub run_trigger
{
	my( $self, $type, %params ) = @_;

	my $fs = $self->config( "triggers", $type );
	return if !defined $fs;

	$params{repository} = $self;

	my $rc;

	TRIGGER: foreach my $priority ( sort { $a <=> $b } keys %{$fs} )
	{
		foreach my $f ( @{$fs->{$priority}} )
		{
			$rc = &{$f}( %params );
			last TRIGGER if defined $rc && $rc eq EP_TRIGGER_DONE;
		}
	}
}

######################################################################
=pod

=item $repository->log( $msg )

Calls the log method from ArchiveConfig.pm for this repository with the 
given parameters. Basically logs the comments wherever the site admin
wants them to go. Printed to STDERR by default.

=cut
######################################################################

sub log
{
	my( $self , $msg) = @_;

	if( $self->config( 'show_ids_in_log' ) )
	{
		my @m2 = ();
		foreach my $line ( split( '\n', $msg ) )
		{
			push @m2,"[".$self->{id}."] ".$line;
		}
		$msg = join("\n",@m2);
	}

	if( $self->can_call( 'log' ) )
	{
		$self->call( 'log', $self, $msg );
	}
	else
	{
		print STDERR "$msg\n";
	}
}


######################################################################
=pod

=item $result = $repository->call( $cmd, @params )

Calls the subroutine named $cmd from the configuration perl modules
for this repository with the given params and returns the result.

=cut
######################################################################

sub call
{
	my( $self, $cmd, @params ) = @_;
	
	my $fn;
	if( ref $cmd eq "ARRAY" )
	{
		$fn = $self->config( @$cmd );
		$cmd = join( "->",@{$cmd} );
	}
	else
	{
		$fn = $self->config( $cmd );
	}

	if( !defined $fn || ref $fn ne "CODE" )
	{
		# Can't log, as that could cause a loop.
		Carp::carp( "Undefined or invalid function: $cmd\n" );
		return;
	}

	my( $r, @r );
	if( wantarray )
	{
		@r = eval { return &$fn( @params ) };
	}
	else
	{
		$r = eval { return &$fn( @params ) };
	}
	if( $@ )
	{
		print "$@\n";
		exit 1;
	}
	return wantarray ? @r : $r;
}

######################################################################
=pod

=item $boolean = $repository->can_call( @cmd_conf_path )

Return true if the given subroutine exists in this repository's config
package.

=cut
######################################################################

sub can_call
{
	my( $self, @cmd_conf_path ) = @_;
	
	my $fn = $self->config( @cmd_conf_path );
	return( 0 ) unless( defined $fn );

	return( 0 ) unless( ref $fn eq "CODE" );

	return 1;
}

######################################################################
=pod

=item $result = $repository->try_call( $cmd, @params )

Calls the subroutine named $cmd from the configuration perl modules
for this repository with the given params and returns the result.

If the subroutine does not exist then quietly returns undef.

This is used to call deprecated callback subroutines.

=cut
######################################################################

sub try_call
{
	my( $self, $cmd, @params ) = @_;

	return unless $self->can_call( $cmd );

	return $self->call( $cmd, @params );
}

######################################################################
=pod

=begin InternalDoc

=item @dirs = $repository->get_store_dirs

Returns a list of directories available for storing documents. These
may well be symlinks to other hard drives.

=end InternalDoc

=cut
######################################################################

sub get_store_dirs
{
	my( $self ) = @_;

	my $docroot = $self->config( "documents_path" );

	opendir( my $dh, $docroot )
		or EPrints->abort( "Error opening document directory $docroot: $!" );

	my( @dirs, $dir );
	foreach my $dir (sort readdir( $dh ))
	{
		next if( $dir =~ m/^\./ );
		next unless( -d $docroot."/".$dir );
		push @dirs, $dir;	
	}

	closedir( $dh );

	if( !@dirs )
	{
		EPrints->system->mkdir( "$docroot/disk0" )
			or EPrints->abort( "No storage directories found in $docroot" );
		push @dirs, "disk0";
	}

	return @dirs;
}

sub get_store_dir
{
	my( $self ) = @_;

	my @dirs = $self->get_store_dirs;

	# df not available, just return last dir found
	return $dirs[$#dirs] if $self->config( "disable_df" );

	my $root = $self->config( "documents_path" );

	my $warnsize = $self->config( "diskspace_warn_threshold" );
	my $errorsize = $self->config( "diskspace_error_threshold" );

	my $warn = 1;
	my $error = 1;

	my %space;
	foreach my $dir (@dirs)
	{
		my $space = EPrints::Platform::free_space( "$root/$dir" );
		$space{$dir} = $space;
		if( $space > $errorsize )
		{
			$error = 0;
		}
		if( $space > $warnsize )
		{
			$warn = 0;
		}
	}

	@dirs = sort { $space{$a} <=> $space{$b} } @dirs;

	# Check that we do have a place for the new directory
	if( $error )
	{
		# Argh! Running low on disk space overall.
		$self->log(<<END);
*** URGENT ERROR
*** Out of disk space.
*** All available drives have under $errorsize kilobytes remaining.
*** No new eprints may be added until this is rectified.
END
		$self->mail_administrator( "lib/eprint:diskout_sub", "lib/eprint:diskout" );
	}
	# Warn the administrator if we're low on space
	elsif( $warn )
	{
		$self->log(<<END);
Running low on diskspace.
All available drives have under $warnsize kilobytes remaining.
END
		$self->mail_administrator( "lib/eprint:disklow_sub", "lib/eprint:disklow" );
	}

	# return the store with the most space available
	return $dirs[$#dirs];
}

=item @dirs = $repository->template_dirs( $langid )

Returns a list of directories from which template files may be sourced, where the first matching template encountered is used.

The directories searched are:

	archives/[archiveid]/cfg/lang/[langid]/templates/
	archives/[archiveid]/cfg/templates/
	archives/[archiveid]/cfg/themes/[themeid]/lang/[langid]/templates/
	archives/[archiveid]/cfg/themes/[themeid]/templates/
	lib/themes/[themeid]/templates/
	lib/lang/[langid]/templates/
	lib/templates/

=cut

sub template_dirs
{
	my( $self, $langid ) = @_;

	my @dirs;

	my $config_path = $self->config( "config_path" );
	my $lib_path = $self->config( "lib_path" );

	# themes path: /archives/[repoid]/cfg/lang/[langid]templates/
	push @dirs, "$config_path/lang/$langid/templates";
	# repository path: /archives/[repoid]/cfg/templates/
	push @dirs, "$config_path/templates";

	my $theme = $self->config( "theme" );
	if( defined $theme )
	{	
		# themes path: /archives/[repoid]/cfg/themes/lang/[langid]templates/
		push @dirs, "$config_path/themes/$theme/lang/$langid/templates";
		# themes path: /archives/[repoid]/cfg/themes/lang/[langid]templates/
		push @dirs, "$config_path/themes/$theme/templates";
		push @dirs, "$lib_path/themes/$theme/templates";
	}

	# system path: /lib/templates/
	push @dirs, "$lib_path/lang/$langid/templates";
	push @dirs, "$lib_path/templates";

	return @dirs;
}

######################################################################
=pod

=begin InternalDoc

=item @dirs = $repository->get_static_dirs( $langid )

Returns a list of directories from which static files may be sourced.

Directories are returned in order of importance, most important first.

=end InternalDoc

=cut
######################################################################

sub get_static_dirs
{
	my( $self, $langid ) = @_;

	my @dirs;

	my $config_path = $self->config( "config_path" );
	my $lib_path = $self->config( "lib_path" );
	my $site_lib_path = $self->config( "base_path" )."/site_lib";

	# repository path: /archives/[repoid]/cfg/static/
	push @dirs, "$config_path/lang/$langid/static";
	push @dirs, "$config_path/static";

	# themes path: /archives/[repoid]/cfg/themes/
	my $theme = $self->config( "theme" );
	if( defined $theme )
	{	
		push @dirs, "$config_path/themes/$theme/static";
		push @dirs, "$lib_path/themes/$theme/static";
	}

	# system path: /lib/static/
	push @dirs, "$lib_path/lang/$langid/static";
	push @dirs, "$lib_path/static";

	# site_lib
	push @dirs, "$site_lib_path/lang/$langid/static";
	push @dirs, "$site_lib_path/static";

	return @dirs;
}

######################################################################
=pod

=begin InternalDoc

=item $size = $repository->get_store_dir_size( $dir )

Returns the current storage (in bytes) used by a given documents dir.
$dir should be one of the values returned by $repository->get_store_dirs.

This should not be called if disable_df is set in SystemSettings.

=end InternalDoc

=cut
######################################################################

sub get_store_dir_size
{
	my( $self , $dir ) = @_;

	my $filepath = $self->config( "documents_path" )."/".$dir;

	if( ! -d $filepath )
	{
		return undef;
	}

	return EPrints::Platform::free_space( $filepath );
} 




######################################################################
=pod

=begin InternalDoc

=item $domdocument = $repository->parse_xml( $file, $no_expand );

Turns the given $file into a XML DOM document. If $no_expand
is true then load &entities; but do not expand them to the values in
the DTD.

This function also sets the path in which the Parser will look for 
DTD files to the repository's config directory.

Returns undef if an error occurs during parsing.

=end InternalDoc

=cut
######################################################################

sub parse_xml
{
	my( $self, $file, $no_expand ) = @_;

	my $lib_path = $self->config( "lib_path" ) . "/";

	my $doc = eval { $self->xml->parse_file( $file,
		base_path => $lib_path,
		no_expand => $no_expand ) };
	if( !defined $doc )
	{
		$self->log( "Failed to parse XML file: $file: $@ ($lib_path)" );
	}

	return $doc;
}


######################################################################
=pod

=item $id = $repository->id 

Returns the id string of this repository.

=cut
######################################################################

*get_id = \&id;
sub id 
{
	my( $self ) = @_;

	return $self->{id};
}


######################################################################
=pod

=item $returncode = $repository->exec( $cmd_id, %map )

Executes a system command. $cmd_id is the id of the command as
set in SystemSettings and %map contains a list of things to "fill in
the blanks" in the invocation line in SystemSettings. 

=cut
######################################################################

sub exec
{
	my( $self, $cmd_id, %map ) = @_;

	return EPrints::Platform::exec( $self, $cmd_id, %map );
}

=begin InternalDoc

=item $returncode = $repository->read_exec( $fh, $cmd_id, %map )

Executes a system command and captures the output, see L</exec>.

=end InternalDoc

=cut

sub read_exec
{
	my( $self, $fh, $cmd_id, %map ) = @_;

	return EPrints::Platform::read_exec( $self, $fh, $cmd_id, %map );
}

sub can_execute
{
	my( $self, $cmd_id ) = @_;

	my $cmd = $self->config( "executables", $cmd_id );

	return ($cmd and $cmd ne "NOTFOUND") ? 1 : 0;
}

sub can_invoke
{
	my( $self, $cmd_id, %map ) = @_;

	my $execs = $self->config( "executables" );

	foreach( keys %{$execs} )
	{
		$map{$_} = $execs->{$_} unless $execs->{$_} eq "NOTFOUND";
	}

	my $command = $self->config( "invocation" )->{ $cmd_id };
	
	return 0 if( !defined $command );

	$command =~ s/\$\(([a-z]*)\)/quotemeta($map{$1})/gei;

	return 0 if( $command =~ /\$\([a-z]*\)/i );

	return 1;
}

######################################################################
=pod

=begin InternalDoc

=item $commandstring = $repository->invocation( $cmd_id, %map )

Finds the invocation for the specified command from SystemSetting and
fills in the blanks using %map. Returns a string which may be executed
as a system call.

All arguments are ESCAPED using quotemeta() before being used (i.e. don't
pre-escape arguments in %map).

=end InternalDoc

=cut
######################################################################

sub invocation
{
	my( $self, $cmd_id, %map ) = @_;

	my $execs = $self->config( "executables" );

	my $command = $self->config( "invocation" )->{ $cmd_id };

	# platform-specific quoting
	$command =~ s/\$\(([a-z0-9_]+)\)/
		exists($map{$1}) ?
			EPrints->system->quotemeta($map{$1}) :
			EPrints->system->quotemeta($execs->{$1})
	/gei;

	return $command;
}

######################################################################
=pod

=begin InternalDoc

=item $defaults = $repository->get_field_defaults( $fieldtype )

Return the cached default properties for this metadata field type.
or undef.

=end InternalDoc

=cut
######################################################################

sub get_field_defaults
{
	my( $self, $fieldtype ) = @_;

	return $self->{field_defaults}->{$fieldtype};
}

######################################################################
=pod

=begin InternalDoc

=item $repository->set_field_defaults( $fieldtype, $defaults )

Cache the default properties for this metadata field type.

=end InternalDoc

=cut
######################################################################

sub set_field_defaults
{
	my( $self, $fieldtype, $defaults ) = @_;

	$self->{field_defaults}->{$fieldtype} = $defaults;
}

######################################################################
=pod

=item ( $returncode, $output) = $repository->test_config

This runs "epadmin test" as an external script to test if the current
configuraion on disk loads OK. This can be used by the web interface
to test if changes to config. files may be saved, or not.

$returncode will be zero if everything seems OK.

If not, then $output will contain the output of epadmin test 

=cut
######################################################################

sub test_config
{
	my( $self ) = @_;

	my $rc = 0;
	my $output = "";

	my $tmp = File::Temp->new;

	$rc = EPrints::Platform::read_perl_script( $self, $tmp, "-e", 
'use EPrints qw( no_check_user ); my $ep = EPrints->new(); my $repo = $ep->repository( "'.$self->{id}.'" ); '
 );

	while(<$tmp>)
	{
		$output .= $_;
	}

	return ($rc/256, $output);
}

=item $ok = $repository->reload_config

Trigger a configuration reload on the next request/index.

To reload the configuration right now just call L</load_config>.

=cut

sub reload_config
{
	my( $self ) = @_;

	my $file = $self->config( "variables_path" )."/last_changed.timestamp";
	if( open(my $fh, ">", $file) )
	{
		print $fh "This file last poked at: ".EPrints::Time::human_time()."\n";
		close $fh;
	}
	else
	{
		$self->log( "Error writing to $file: $!" );
		return 0;
	}

	return 1;
}

######################################################################
=pod

=begin InternalDoc

=item $langid = EPrints::Repository::get_session_language( $repository, $request )

Given an repository object and a Apache (mod_perl) request object, this
method decides what language the session should be.

First it looks at the HTTP cookie "eprints_lang", failing that it
looks at the prefered language of the request from the HTTP header,
failing that it looks at the default language for the repository.

The language ID it returns is the highest on the list that the given
eprint repository actually supports.

=end InternalDoc

=cut
######################################################################

sub get_session_language
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

=begin InternalDoc

=item $repository->change_lang( $newlangid )

Change the current language of the session. $newlangid should be a
valid country code for the current repository.

An invalid code will cause eprints to terminate with an error.

=end InternalDoc

=cut
######################################################################

sub change_lang
{
	my( $self, $newlangid ) = @_;

	if( !defined $newlangid )
	{
		$newlangid = $self->get_conf( "defaultlanguage" );
	}
	$self->{lang} = $self->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
}


######################################################################
=pod

=begin InternalDoc

=item $xhtml_phrase = $repository->html_phrase( $phraseid, %inserts )

Return an XHTML DOM object describing a phrase from the phrase files.

$phraseid is the id of the phrase to return. If the same ID appears
in both the repository-specific phrases file and the system phrases file
then the repository-specific one is used.

If the phrase contains <ep:pin> elements, then each one should have
an entry in %inserts where the key is the "ref" of the pin and the
value is an XHTML DOM object describing what the pin should be 
replaced with.

=end InternalDoc

=cut
######################################################################

sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
	# $phraseid [ASCII] 
	# %inserts [HASH: ASCII->DOM]
	#
	# returns [DOM]	
        
	$self->{used_phrases}->{$phraseid} = 1;

	my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );
	#my $s = $self->make_element( "span", title=>$phraseid );
	#$s->appendChild( $r );
	#return $s;

	return $r;
}


######################################################################
=pod

=begin InternalDoc

=item $utf8_text = $repository->phrase( $phraseid, %inserts )

Performs the same function as html_phrase, but returns plain text.

All HTML elements will be removed, <br> and <p> will be converted 
into breaks in the text. <img> tags will be replaced with their 
"alt" values.

=end InternalDoc

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
=pod

=begin InternalDoc

=item $language = $repository->get_lang

Return the EPrints::Language object for this sessions current 
language.

=end InternalDoc

=cut
######################################################################

sub get_lang
{
	my( $self ) = @_;

	return $self->{lang};
}


######################################################################
=pod

=begin InternalDoc

=item $langid = $repository->get_langid

Return the ID code of the current language of this session.

=end InternalDoc

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

=begin InternalDoc

=item $value = EPrints::Repository::best_language( $repository, $lang, %values )

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

This means that the view sees the best possible phrase. 

=end InternalDoc

=cut
######################################################################

sub best_language
{
	my( $repository, $lang, %values ) = @_;

	# no options?
	return undef if( scalar keys %values == 0 );

	# The language of the current session is best
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
=pod

=begin InternalDoc

=item $viewname = $repository->get_view_name( $dataset, $viewid )

Return a UTF8 encoded string containing the human readable name
of the /view/ section with the ID $viewid.

=end InternalDoc

=cut
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}

######################################################################
=pod

=begin InternalDoc

=item $db = $repository->get_database

Return the current EPrints::Database connection object.

=end InternalDoc

=cut
######################################################################
sub get_db { return $_[0]->get_database; } # back compatibility

sub database { shift->get_database( @_ ) }
sub get_database
{
	my( $self ) = @_;
	return $self->{database};
}

=begin InternalDoc

=item $store = $repository->get_storage

Return the storage control object.

=end InternalDoc

=cut

sub get_storage
{
	my( $self ) = @_;
	return $self->{storage};
}



######################################################################
=pod

=begin InternalDoc

=item $repository = $repository->get_repository

Return the EPrints::Repository object associated with the Repository.

=end InternalDoc

=cut
######################################################################
sub get_archive { return $_[0]->get_repository; }

sub get_repository
{
	my( $self ) = @_;
	return $self;
}


######################################################################
=pod

=begin InternalDoc

=item $url = $repository->current_url( [ @OPTS ] [, $page] )

Utility method to get various URLs. See L<EPrints::URL>.

With no arguments returns the current full URL without any query part.

	# Return the current static path
	$repository->current_url( path => "static" );

	# Return the current cgi path
	$repository->current_url( path => "cgi" );

	# Return a full URL to the current cgi path
	$repository->current_url( host => 1, path => "cgi" );

	# Return a full URL to the static path under HTTP
	$repository->current_url( scheme => "http", host => 1, path => "static" );

	# Return a full URL to the image 'foo.png'
	$repository->current_url( host => 1, path => "images", "foo.png" );

=end InternalDoc

=cut
######################################################################

sub get_url { &current_url }
sub current_url
{
	my( $self, @opts ) = @_;

	my $url = EPrints::URL->new( session => $self );

	return $url->get( @opts );
}

######################################################################
=pod

=begin InternalDoc

=item $uri = $repository->get_uri

Returns the URL of the current script. Or "undef".

=end InternalDoc

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

=begin InternalDoc

=item $uri = $repository->get_full_url

Returns the URL of the current script plus the CGI params.

=end InternalDoc

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

=begin InternalDoc

=item $noise_level = $repository->get_noise

Return the noise level for the current session. See the explaination
under EPrints::Repository->new()

=end InternalDoc

=cut
######################################################################

sub get_noise
{
	my( $self ) = @_;
	
	return( $self->{noise} );
}


######################################################################
=pod

=begin InternalDoc

=item $boolean = $repository->is_online

Return true if this script is running via CGI, return false if we're
on the command line.

=end InternalDoc

=cut
######################################################################

sub get_online { &is_online }
sub is_online
{
	my( $self ) = @_;
	
	return( !$self->{offline} );
}

######################################################################
=pod

=begin InternalDoc

=item $secure = $repository->is_secure

Returns true if we're using HTTPS/SSL (checks get_online first).

=end InternalDoc

=cut
######################################################################

sub get_secure { &is_secure }
sub is_secure
{
	my( $self ) = @_;

	# mod_ssl sets "HTTPS", but only AFTER the Auth stage
	return $self->is_online &&
		($ENV{"HTTPS"} || $self->get_request->dir_config( 'EPrints_Secure' ));
}



#############################################################
#############################################################
=pod

=begin InternalDoc

=back

=head2 DOM Related Methods

These methods help build XML. Usually, but not always XHTML.

=over 4

=end InternalDoc

=cut
#############################################################
#############################################################


######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->make_element( $element_name, %attribs )

Return a DOM element with name ename and the specified attributes.

eg. $repository->make_element( "img", src => "/foo.gif", alt => "my pic" )

Will return the DOM object describing:

<img src="/foo.gif" alt="my pic" />

Note that in the call we use "=>" not "=".

=end InternalDoc

=cut
######################################################################

sub make_element
{
	my( $self, $ename , @opts ) = @_;
	return $self->xml->create_element( $ename, @opts );
}


######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->make_indent( $width )

Return a DOM object describing a C.R. and then $width spaces. This
is used to make nice looking XML for things like the OAI interface.

=end InternalDoc

=cut
######################################################################

sub make_indent
{
	my( $self, $width ) = @_;
	return $self->xml->create_text_node( "\n"." "x$width );
}

######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->make_comment( $text )

Return a DOM object describing a comment containing $text.

eg.

<!-- this is a comment -->

=end InternalDoc

=cut
######################################################################

sub make_comment
{
	my( $self, $text ) = @_;
	$self->xml->create_comment( $text );
}
	

# $text is a UTF8 String!

######################################################################
=pod

=begin InternalDoc

=item $DOM = $repository->make_text( $text )

Return a DOM object containing the given text. $text should be
UTF-8 encoded.

Characters will be treated as _text_ including < > etc.

eg.

$repository->make_text( "This is <b> an example" );

Would return a DOM object representing the XML:

"This is &lt;b&gt; an example"

=end InternalDoc

=cut
######################################################################

sub make_text
{
	my( $self, $text ) = @_;

	return $self->xml->create_document_fragment if !defined $text;

	return $self->xml->create_text_node( $text );
}

######################################################################
=pod

=begin InternalDoc

=item $DOM = $repository->make_javascript( $code, %attribs )

Return a new DOM "script" element containing $code in javascript. %attribs will
be added to the script element, similar to make_element().

E.g.

	<script type="text/javascript">
	// <![CDATA[
	alert("Hello, World!");
	// ]]>
	</script>

=end InternalDoc

=cut
######################################################################

sub make_javascript
{
	my( $self, $text, %attr ) = @_;

	my $script = $self->xml->create_element( "script", type => "text/javascript", %attr );

	if( defined $text )
	{
		chomp($text);
		$script->appendChild( $self->xml->create_text_node( "\n// " ) );
		$script->appendChild( $self->xml->create_cdata_section( "\n$text\n// " ) );
	}
	else
	{
		$script->appendChild( $self->xml->create_comment( "padder" ) );
	}

	return $script;
}

######################################################################
=pod

=begin InternalDoc

=item $fragment = $repository->make_doc_fragment

Return a new XML document fragment. This is an item which can have
XML elements added to it, but does not actually get rendered itself.

If appended to an element then it disappears and its children join
the element at that point.

=end InternalDoc

=cut
######################################################################

sub make_doc_fragment
{
	my( $self ) = @_;
	return $self->xml->create_document_fragment;
}






#############################################################
#############################################################
=pod

=begin InternalDoc

=back

=head2 XHTML Related Methods

These methods help build XHTML.

=over 4

=end InternalDoc

=cut
#############################################################
#############################################################




######################################################################
=pod

=begin InternalDoc

=item $ruler = $repository->render_ruler

Return an HR.
in ruler.xml

=end InternalDoc

=cut
######################################################################

sub render_ruler
{
	my( $self ) = @_;

	return $self->html_phrase( "ruler" );
}

######################################################################
=pod

=begin InternalDoc

=item $nbsp = $repository->render_nbsp

Return an XHTML &nbsp; character.

=end InternalDoc

=cut
######################################################################

sub render_nbsp
{
	my( $self ) = @_;

	my $string = pack("U",160);

	return $self->make_text( $string );
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml = $repository->render_data_element( $indent, $elementname, $value, [%opts] )

This is used to help render neat XML data. It returns a fragment 
containing an element of name $elementname containing the value
$value, the element is indented by $indent spaces.

The %opts describe any extra attributes for the element

eg.
$repository->render_data_element( 4, "foo", "bar", class=>"fred" )

would return a XML DOM object describing:
    <foo class="fred">bar</foo>

=end InternalDoc

=cut
######################################################################

sub render_data_element
{
	my( $self, $indent, $elementname, $value, %opts ) = @_;

	return $self->xhtml->data_element( $elementname, $value,
		indent => $indent,
		%opts );
}


######################################################################
=pod

=begin InternalDoc

=item $xhtml = $repository->render_link( $uri, [$target] )

Returns an HTML link to the given uri, with the optional $target if
it needs to point to a different frame or window.

=end InternalDoc

=cut
######################################################################

sub render_link
{
	my( $self, $uri, $target ) = @_;

	return $self->make_element(
		"a",
		href=>$uri,
		target=>$target );
}

######################################################################
=pod

=begin InternalDoc

=item $table_row = $repository->render_row( $key, @values );

Return the key and values in a DOM encoded HTML table row. eg.

 <tr><th>$key:</th><td>$value[0]</td><td>...</td></tr>

=end InternalDoc

=cut
######################################################################

sub render_row
{
	my( $repository, $key, @values ) = @_;

	my( $tr, $th, $td );

	$tr = $repository->make_element( "tr" );

	$th = $repository->make_element( "th", valign=>"top", class=>"ep_row" ); 
	if( !defined $key )
	{
		$th->appendChild( $repository->render_nbsp );
	}
	else
	{
		$th->appendChild( $key );
		$th->appendChild( $repository->make_text( ":" ) );
	}
	$tr->appendChild( $th );

	foreach my $value ( @values )
	{
		$td = $repository->make_element( "td", valign=>"top", class=>"ep_row" ); 
		$td->appendChild( $value );
		$tr->appendChild( $td );
	}

	return $tr;
}

# parts...
#
#        help: dom of help text
#       label: dom title of row (to go in <th>)
#       class: class for <tr>
#       field: dom content for <td>
# help_prefix: prefix for id tag of help toggle
#   no_toggle: if true, renders the help always on with no toggle
#     no_help: don't actually render help or a toggle (for rendering same styled rows in the same table)

sub render_row_with_help
{
	my( $self, %parts ) = @_;

	if( defined $parts{help} && EPrints::XML::is_empty( $parts{help} ) )
	{
		delete $parts{help};
	}


	my $tr = $self->make_element( "tr", class=>$parts{class} );

	#
	# COL 1
	#
	my $th = $self->make_element( "th", class=>"ep_multi_heading" );
	$th->appendChild( $parts{label} );
	$th->appendChild( $self->make_text( ":" ) );
	$tr->appendChild( $th );

	if( !defined $parts{help} || $parts{no_help} )
	{
		my $td = $self->make_element( "td", class=>"ep_multi_input", colspan=>"2" );
		$tr->appendChild( $td );
		$td->appendChild( $parts{field} );
		return $tr;
	}

	#
	# COL 2
	#
	
	my $inline_help_class = "ep_multi_inline_help";
	my $colspan = "2";
	if( !$parts{no_toggle} ) 
	{ 
		# ie, yes to toggle
		$inline_help_class .= " ep_no_js"; 
		$colspan = 1;
	}

	my $td = $self->make_element( "td", class=>"ep_multi_input", colspan=>$colspan, id=>$parts{help_prefix}."_outer" );
	$tr->appendChild( $td );

	my $inline_help = $self->make_element( "div", id=>$parts{help_prefix}, class=>$inline_help_class );
	my $inline_help_inner = $self->make_element( "div", id=>$parts{help_prefix}."_inner" );
	$inline_help->appendChild( $inline_help_inner );
	$inline_help_inner->appendChild( $parts{help} );
	$td->appendChild( $inline_help );

	$td->appendChild( $parts{field} );

	if( $parts{no_toggle} ) 
	{ 
		return $tr;
	}
		
	#
	# COL 3
	# help toggle
	#

	my $td2 = $self->make_element( "td", class=>"ep_multi_help ep_only_js_table_cell ep_toggle" );
	my $show_help = $self->make_element( "div", class=>"ep_sr_show_help ep_only_js", id=>$parts{help_prefix}."_show" );
	my $helplink = $self->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$parts{help_prefix}',false,'block');EPJS_toggle('$parts{help_prefix}_hide',false,'block');EPJS_toggle('$parts{help_prefix}_show',true,'block');return false", href=>"#" );
	$show_help->appendChild( $self->html_phrase( "lib/session:show_help",link=>$helplink ) );
	$td2->appendChild( $show_help );

	my $hide_help = $self->make_element( "div", class=>"ep_sr_hide_help ep_hide", id=>$parts{help_prefix}."_hide" );
	my $helplink2 = $self->make_element( "a", onclick => "EPJS_blur(event); EPJS_toggleSlide('$parts{help_prefix}',false,'block');EPJS_toggle('$parts{help_prefix}_hide',false,'block');EPJS_toggle('$parts{help_prefix}_show',true,'block');return false", href=>"#" );
	$hide_help->appendChild( $self->html_phrase( "lib/session:hide_help",link=>$helplink2 ) );
	$td2->appendChild( $hide_help );
	$tr->appendChild( $td2 );

	return $tr;
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml = $repository->render_language_name( $langid ) 
Return a DOM object containing the description of the specified language
in the current default language, or failing that from languages.xml

=end InternalDoc

=cut
######################################################################

sub render_language_name
{
	my( $self, $langid ) = @_;

	my $phrasename = 'languages_typename_'.$langid;

	return $self->html_phrase( $phrasename );
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml = $repository->render_type_name( $type_set, $type ) 

Return a DOM object containing the description of the specified type
in the type set. eg. "eprint", "article"

=end InternalDoc

=cut
######################################################################

sub render_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->html_phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=begin InternalDoc

=item $string = $repository->get_type_name( $type_set, $type ) 

As above, but return a utf-8 string. Used in <option> elements, for
example.

=end InternalDoc

=cut
######################################################################

sub get_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml_name = $repository->render_name( $name, [$familylast] )

$name is a ref. to a hash containing family, given etc.

Returns an XML DOM fragment with the name rendered in the manner
of the repository. Usually "John Smith".

If $familylast is set then the family and given parts are reversed, eg.
"Smith, John"

=end InternalDoc

=cut
######################################################################

sub render_name
{
	my( $self, $name, $familylast ) = @_;

	my $namestr = EPrints::Utils::make_name_string( $name, $familylast );

	my $span = $self->make_element( "span", class=>"person_name" );
		
	$span->appendChild( $self->make_text( $namestr ) );

	return $span;
}

######################################################################
=pod

=begin InternalDoc

=item $xhtml_select = $repository->render_option_list( %params )

This method renders an XHTML <select>. The options are complicated
and may change, so it's better not to use it.

=end InternalDoc

=cut
######################################################################

sub render_option_list
{
	my( $self , %params ) = @_;

	#params:
	# default  : array or scalar
	# height   :
	# multiple : allow multiple selections
	# pairs    :
	# values   :
	# labels   :
	# name     :
	# checkbox :
	# defaults_at_top : move items already selected to top
	# 			of list, so they are visible.

	my %defaults = ();
	if( ref( $params{default} ) eq "ARRAY" )
	{
		foreach( @{$params{default}} )
		{
			$defaults{$_} = 1;
		}
	}
	elsif( defined $params{default} )
	{
		$defaults{$params{default}} = 1;
	}


	my $dtop = defined $params{defaults_at_top} && $params{defaults_at_top};


	my @alist = ();
	my @list = ();
	my $pairs = $params{pairs};
	if( !defined $pairs )
	{
		$pairs = [];
		foreach( @{$params{values}} )
		{
			push @{$pairs}, [ $_, $params{labels}->{$_} ];
		}
	}		
						
	if( $dtop && scalar keys %defaults )
	{
		my @pairsa;
		my @pairsb;
		foreach my $pair (@{$pairs})
		{
			if( $defaults{$pair->[0]} )
			{
				push @pairsa, $pair;
			}
			else
			{
				push @pairsb, $pair;
			}
		}
		$pairs = [ @pairsa, [ '-', '----------' ], @pairsb ];
	}

	if( $params{checkbox} )
	{
		my $table = $self->make_element( "table", cellspacing=>"10", border=>"0", cellpadding=>"0" );
		my $tr = $self->make_element( "tr" );
		$table->appendChild( $tr );	
		my $td = $self->make_element( "td", valign=>"top" );
		$tr->appendChild( $td );	
		my $i = 0;
		my $len = scalar @$pairs;
		foreach my $pair ( @{$pairs} )
		{
			my $div = $self->make_element( "div" );
			my $label = $self->make_element( "label" );
			$div->appendChild( $label );
			my $box = $self->render_input_field( type=>"checkbox", name=>$params{name}, value=>$pair->[0], class=>"ep_form_checkbox" );
			$label->appendChild( $box );
			$label->appendChild( $self->make_text( " ".$pair->[1] ) );
			if( $defaults{$pair->[0]} )
			{
				$box->setAttribute( "checked" , "checked" );
			}
			$td->appendChild( $div );
			++$i;
			if( $len > 5 && int($len / 2)==$i )
			{
				$td = $self->make_element( "td", valign=>"top" );
				$tr->appendChild( $td );	
			}
		}
		return $table;
	}
		


	my $element = $self->make_element( "select" , name => $params{name}, id => $params{name} );
	if( $params{multiple} )
	{
		$element->setAttribute( "multiple" , "multiple" );
	}
	my $size = 0;
	foreach my $pair ( @{$pairs} )
	{
		$element->appendChild( 
			$self->render_single_option(
				$pair->[0],
				$pair->[1],
				$defaults{$pair->[0]} ) );
		$size++;
	}
	if( defined $params{height} )
	{
		if( $params{height} ne "ALL" )
		{
			if( $params{height} < $size )
			{
				$size = $params{height};
			}
		}
		$element->setAttribute( "size" , $size );
	}
	return $element;
}



######################################################################
=pod

=begin InternalDoc

=item $option = $repository->render_single_option( $key, $desc, $selected )

Used by render_option_list.

=end InternalDoc

=cut
######################################################################

sub render_single_option
{
	my( $self, $key, $desc, $selected ) = @_;

	my $opt = $self->make_element( "option", value => $key );
	$opt->appendChild( $self->make_text( $desc ) );

	if( $selected )
	{
		$opt->setAttribute( "selected" , "selected" );
	}
	return $opt;
}


######################################################################
=pod

=begin InternalDoc

=item $xhtml_hidden = $repository->render_hidden_field( $name, $value )

Return the XHTML DOM describing an <input> element of type "hidden"
and name and value as specified. eg.

<input type="hidden" name="foo" value="bar" />

=end InternalDoc

=cut
######################################################################

sub render_hidden_field
{
	my( $self, $name, $value ) = @_;

	if( !defined $value ) 
	{
		$value = $self->param( $name );
	}

	return $self->xhtml->hidden_field( $name, $value );
}

sub render_input_field
{
	my( $self, %opts ) = @_;

	$opts{type} = 'text' unless( exists $opts{type} );

	return $self->xhtml->input_field(
		delete($opts{name}),
		delete($opts{value}),
		%opts );
}

sub render_noenter_input_field
{
	my( $self, %opts ) = @_;
	
	$opts{type} = 'text' unless( exists $opts{type} );

	return $self->xhtml->input_field(
		delete($opts{name}),
		delete($opts{value}),
		noenter => 1,
		%opts );
}


######################################################################
=pod

=begin InternalDoc

=item $xhtml_upload = $repository->render_upload_field( $name )

Render into XHTML DOM a file upload form button with the given name. 

eg.
<input type="file" name="foo" />

=end InternalDoc

=cut
######################################################################

sub render_upload_field
{
	my( $self, $name ) = @_;
	return $self->xhtml->input_field(
		$name,
		undef,
		type => "file" );
}


######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->render_action_buttons( %buttons )

Returns a DOM object describing the set of buttons.

The keys of %buttons are the ids of the action that button will cause,
the values are UTF-8 text that should appear on the button.

Two optional additional keys may be used:

_order => [ "action1", "action2" ]

will force the buttons to appear in a set order.

_class => "my_css_class" 

will add a class attribute to the <div> containing the buttons to 
allow additional styling.

=end InternalDoc

=cut
######################################################################

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "action" , %buttons );
}


######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->render_internal_buttons( %buttons )

As for render_action_buttons, but creates buttons for actions which
will modify the state of the current form, not continue with whatever
process the form is part of.

eg. the "More Spaces" button and the up and down arrows on multiple
type fields.

=end InternalDoc

=cut
######################################################################

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "internal" , %buttons );
}


######################################################################
# 
# $dom = $repository->_render_buttons_aux( $btype, %buttons )
#
######################################################################

sub _render_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	#my $frag = $self->make_doc_fragment();
	my $class;
	if( defined $buttons{_class} )
	{
		$class = $buttons{_class};
	}
	my $div = $self->make_element( "div", class=>$class );

	my @order = keys %buttons;
	if( defined $buttons{_order} )
	{
		@order = @{$buttons{_order}};
	}

	my $button_id;
	foreach $button_id ( @order )
	{
		# skip options which start with a "_" they are params
		# not buttons.
		next if( $button_id eq '_class' );
		next if( $button_id eq '_order' );
		$div->appendChild(
			$self->render_button( 
				name => "_".$btype."_".$button_id, 
				class => "ep_form_".$btype."_button",
				value => $buttons{$button_id} ) );

		# Some space between butons.
		$div->appendChild( $self->make_text( " " ) );
	}

	return( $div );
}

sub render_button
{
	my( $self, %opts ) = @_;

	if( !defined $opts{class} )
	{
		$opts{class} = "ep_form_action_button";
	}
	$opts{type} = "submit";

	return $self->make_element( "input", %opts );
}

######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->render_form( $method, $dest )

Return a DOM object describing an HTML form element. 

$method should be "get" or "post"

$dest is the target of the form. By default the current page.

eg.

$repository->render_form( "GET", "http://example.com/cgi/foo" );

returns a DOM object representing:

<form method="get" action="http://example.com/cgi/foo" accept-charset="utf-8" />

If $method is "post" then an addition attribute is set:
enctype="multipart/form-data" 

This just controls how the data is passed from the browser to the
CGI library. You don't need to worry about it.

=end InternalDoc

=cut
######################################################################

sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	return $self->xhtml->form( $method, $dest );
}


######################################################################
=pod

=begin InternalDoc

=item $ul = $repository->render_subjects( $subject_list, [$baseid], [$currentid], [$linkmode], [$sizes] )

Return as XHTML DOM a nested set of <ul> and <li> tags describing
part of a subject tree.

$subject_list is a array ref of subject ids to render.

$baseid is top top level node to render the tree from. If only a single
subject is in subject_list, all subjects up to $baseid will still be
rendered. Default is the ROOT element.

If $currentid is set then the subject with that ID is rendered in
<strong>

$linkmode can 0, 1, 2 or 3.

0. Don't link the subjects.

1. Links subjects to the URL which edits them in edit_subjects.

2. Links subjects to "subjectid.html" (where subjectid is the id of 
the subject)

3. Links the subjects to "subjectid/".  $sizes must be set. Only 
subjects with a size of more than one are linked.

4. Links the subjects to "../subjectid/".  $sizes must be set. Only 
subjects with a size of more than one are linked.

$sizes may be a ref. to hash mapping the subjectid's to the number
of items in that subject which will be rendered in brackets next to
each subject.

=end InternalDoc

=cut
######################################################################

sub render_subjects
{
	my( $self, $subject_list, $baseid, $currentid, $linkmode, $sizes ) = @_;

	# If sizes is defined then it contains a hash subjectid->#of subjects
	# we don't do this ourselves.

#cjg NO SUBJECT_LIST = ALL SUBJECTS under baseid!
	if( !defined $baseid )
	{
		$baseid = $EPrints::DataObj::Subject::root_subject;
	}

	my %subs = ();
	foreach( @{$subject_list}, $baseid )
	{
		$subs{$_} = EPrints::DataObj::Subject->new( $self, $_ );
	}

	return $self->_render_subjects_aux( \%subs, $baseid, $currentid, $linkmode, $sizes );
}

######################################################################
# 
# $ul = $repository->_render_subjects_aux( $subjects, $id, $currentid, $linkmode, $sizes )
#
# Recursive subroutine needed by render_subjects.
#
######################################################################

sub _render_subjects_aux
{
	my( $self, $subjects, $id, $currentid, $linkmode, $sizes ) = @_;

	my( $ul, $li, $elementx );
	$ul = $self->make_element( "ul" );
	$li = $self->make_element( "li" );
	$ul->appendChild( $li );
	if( defined $currentid && $id eq $currentid )
	{
		$elementx = $self->make_element( "strong" );
	}
	else
	{
		if( $linkmode == 1 )
		{
			$elementx = $self->render_link( "?screen=Subject::Edit&subjectid=".$id ); 
		}
		elsif( $linkmode == 2 )
		{
			$elementx = $self->render_link( 
				EPrints::Utils::escape_filename( $id ).
					".html" ); 
		}
		elsif( $linkmode == 3 )
		{
			$elementx = $self->render_link( 
				EPrints::Utils::escape_filename( $id )."/" ); 
		}
		elsif( $linkmode == 4 )
		{
			$elementx = $self->render_link( 
				"../".EPrints::Utils::escape_filename( $id )."/" ); 
		}
		else
		{
			$elementx = $self->make_element( "span" );
		}
	}
	$li->appendChild( $elementx );
	$elementx->appendChild( $subjects->{$id}->render_description() );
	if( defined $sizes && defined $sizes->{$id} && $sizes->{$id} > 0 )
	{
		$li->appendChild( $self->make_text( " (".$sizes->{$id}.")" ) );
	}
		
	foreach( $subjects->{$id}->get_children() )
	{
		my $thisid = $_->get_value( "subjectid" );
		next unless( defined $subjects->{$thisid} );
		$li->appendChild( $self->_render_subjects_aux( $subjects, $thisid, $currentid, $linkmode, $sizes ) );
	}
	
	return $ul;
}



######################################################################
=pod

=begin InternalDoc

=item $repository->render_error( $error_text, $back_to, $back_to_text )

Renders an error page with the given error text. A link, with the
text $back_to_text, is offered, the destination of this is $back_to,
which should take the user somewhere sensible.

=end InternalDoc

=cut
######################################################################

sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;
	
	if( !defined $back_to )
	{
		$back_to = $self->get_repository->get_conf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
		$back_to_text = $self->html_phrase( "lib/session:continue");
	}

	my $textversion = '';
	$textversion.= $self->phrase( "lib/session:some_error" );
	$textversion.= EPrints::Utils::tree_to_utf8( $error_text, 76 );
	$textversion.= "\n";

	if ( $self->{offline} )
	{
		print $textversion;
		return;
	} 

	# send text version to log
	$self->get_repository->log( $textversion );

	my( $p, $page, $a );
	$page = $self->make_doc_fragment();

	$page->appendChild( $self->html_phrase( "lib/session:some_error"));

	$p = $self->make_element( "p" );
	$p->appendChild( $error_text );
	$page->appendChild( $p );

	$page->appendChild( $self->html_phrase( "lib/session:contact" ) );
				
	$p = $self->make_element( "p" );
	$a = $self->render_link( $back_to ); 
	$a->appendChild( $back_to_text );
	$p->appendChild( $a );
	$page->appendChild( $p );
	$self->build_page(	
		$self->html_phrase( "lib/session:error_title" ),
		$page,
		"error" );

	$self->send_page();
}

my %INPUT_FORM_DEFAULTS = (
	dataset => undef,
	type	=> undef,
	fields => [],
	values => {},
	show_names => 0,
	show_help => 0,
	staff => 0,
	buttons => {},
	hidden_fields => {},
	comments => {},
	dest => undef,
	default_action => undef
);


######################################################################
=pod

=begin InternalDoc

=item $dom = $repository->render_input_form( %params )

Return a DOM object representing an entire input form.

%params contains the following options:

dataset: The EPrints::Dataset to which the form relates, if any.

fields: a reference to an array of EPrint::MetaField objects,
which describe the fields to be added to the form.

values: a set of default values. A reference to a hash where
the keys are ID's of fields, and the values are the default
values for those fields.

show_help: if true, show the fieldhelp phrase for each input 
field.

show_name: if true, show the fieldname phrase for each input 
field.

buttons: a description of the buttons to appear at the bottom
of the form. See render_action_buttons for details.

top_buttons: a description of the buttons to appear at the top
of the form (optional).

default_action: the id of the action to be performed by default, 
ie. if the user pushes "return" in a text field.

dest: The URL of the target for this form. If not defined then
the current URI is used.

type: if this form relates to a user or an eprint, the type of
eprint/user can effect what fields are flagged as required. This
param contains the ID of the eprint/user if any, and if relevant.

staff: if true, this form is being presented to repository staff 
(admin, or editor). This may change which fields are required.

hidden_fields: reference to a hash. The keys of which are CGI keys
and the values are the values they are set to. This causes hidden
form elements to be set, so additional information can be passed.

object: The DataObj which this form is editing, if any.

comment: not yet used.

=end InternalDoc

=cut
######################################################################

sub render_input_form
{
	my( $self, %p ) = @_;

	foreach( keys %INPUT_FORM_DEFAULTS )
	{
		next if( defined $p{$_} );
		$p{$_} = $INPUT_FORM_DEFAULTS{$_};
	}

	my( $form );

	$form =	$self->render_form( "post", $p{dest} );
	if( defined $p{default_action} )
	{
		my $imagesurl = $self->get_repository->get_conf( "rel_path" )."/images";
		# This button will be the first on the page, so
		# if a user hits return and the browser auto-
		# submits then it will be this image button, not
		# the action buttons we look for.

		# It should be a small white on pixel PNG.
		# (a transparent GIF would be slightly better, but
		# GNU has a problem with GIF).
		# The style stops it rendering on modern broswers.
		# under lynx it looks bad. Lynx does not
		# submit when a user hits return so it's 
		# not needed anyway.
		$form->appendChild( $self->make_element( 
			"input", 
			type => "image", 
			width => 1, 
			height => 1, 
			border => 0,
			style => "display: none",
			src => "$imagesurl/whitedot.png",
			name => "_default", 
			alt => $p{buttons}->{$p{default_action}} ) );
		$form->appendChild( $self->render_hidden_field(
			"_default_action",
			$p{default_action} ) );
	}

	if( defined $p{top_buttons} )
	{
		$form->appendChild( $self->render_action_buttons( %{$p{top_buttons}} ) );
	}

	my $field;	
	foreach $field (@{$p{fields}})
	{
		$form->appendChild( $self->_render_input_form_field( 
			$field,
			$p{values}->{$field->get_name()},
			$p{show_names},
			$p{show_help},
			$p{comments}->{$field->get_name()},
			$p{dataset},
			$p{type},
			$p{staff},
			$p{hidden_fields},
			$p{object} ) );
	}

	foreach (keys %{$p{hidden_fields}})
	{
		$form->appendChild( $self->render_hidden_field( 
					$_, 
					$p{hidden_fields}->{$_} ) );
	}
	if( defined $p{comments}->{above_buttons} )
	{
		$form->appendChild( $p{comments}->{above_buttons} );
	}

	$form->appendChild( $self->render_action_buttons( %{$p{buttons}} ) );

	return $form;
}


######################################################################
# 
# $xhtml_field = $repository->_render_input_form_field( $field, $value, $show_names, $show_help, $comment, $dataset, $type, $staff, $hiddenfields, $object )
#
# Render a single field in a form being rendered by render_input_form
#
######################################################################

sub _render_input_form_field
{
	my( $self, $field, $value, $show_names, $show_help, $comment,
			$dataset, $type, $staff, $hidden_fields , $object) = @_;
	
	my( $div, $html, $span );

	$html = $self->make_doc_fragment();

	if( substr( $self->get_internal_button(), 0, length($field->get_name())+1 ) eq $field->get_name()."_" ) 
	{
		my $a = $self->make_element( "a", name=>"t" );
		$html->appendChild( $a );
	}

	my $req = $field->get_property( "required" );

	if( $show_names )
	{
		$div = $self->make_element( "div", class => "ep_form_field_name" );

		# Field name should have a star next to it if it is required
		# special case for booleans - even if they're required it
		# dosn't make much sense to highlight them.	

		my $label = $field->render_name( $self );
		if( $req && !$field->is_type( "boolean" ) )
		{
			$label = $self->html_phrase( "sys:ep_form_required",
				label=>$label );
		}
		$div->appendChild( $label );

		$html->appendChild( $div );
	}

	if( $show_help )
	{
		$div = $self->make_element( "div", class => "ep_form_field_help" );

		$div->appendChild( $field->render_help( $self, $type ) );
		$div->appendChild( $self->make_text( "" ) );

		$html->appendChild( $div );
	}

	$div = $self->make_element( 
		"div", 
		class => "ep_form_field_input",
		id => "inputfield_".$field->get_name );
	$div->appendChild( $field->render_input_field( 
		$self, $value, $dataset, $staff, $hidden_fields , $object ) );
	$html->appendChild( $div );
				
	return( $html );
}	

######################################################################
# 
# $xhtml = $repository->render_toolbox( $title, $content )
#
# Render a toolbox. This method will probably gain a whole bunch of new
# options.
#
# title and content are DOM objects.
#
######################################################################

sub render_toolbox
{
	my( $self, $title, $content ) = @_;

	my $div = $self->make_element( "div", class=>"ep_toolbox" );

	if( defined $title )
	{
		my $title_div = $self->make_element( "div", class=>"ep_toolbox_title" );
		$div->appendChild( $title_div );
		$title_div->appendChild( $title );
	}

	my $content_div = $self->make_element( "div", class=>"ep_toolbox_content" );
	$div->appendChild( $content_div );
	$content_div->appendChild( $content );
	return $div;
}

sub render_message
{
	my( $self, $type, $content, $show_icon ) = @_;
	
	$show_icon = 1 unless defined $show_icon;

	my $id = "m".$self->get_next_id;
	my $div = $self->make_element( "div", class=>"ep_msg_".$type, id=>$id );
	my $content_div = $self->make_element( "div", class=>"ep_msg_".$type."_content" );
	my $table = $self->make_element( "table" );
	my $tr = $self->make_element( "tr" );
	$table->appendChild( $tr );
	if( $show_icon )
	{
		my $td1 = $self->make_element( "td" );
		my $imagesurl = $self->get_repository->get_conf( "rel_path" );
		$td1->appendChild( $self->make_element( "img", class=>"ep_msg_".$type."_icon", src=>"$imagesurl/style/images/".$type.".png", alt=>$self->phrase( "Plugin/Screen:message_".$type ) ) );
		$tr->appendChild( $td1 );
	}
	my $td2 = $self->make_element( "td" );
	$tr->appendChild( $td2 );
	$td2->appendChild( $content );
	$content_div->appendChild( $table );
#	$div->appendChild( $title_div );
	$div->appendChild( $content_div );
	return $div;
}


######################################################################
# 
# $xhtml = $repository->render_tabs( %params )
#
# Render javascript tabs to switch between views. The views must be
# rendered seperately. 

# %params contains the following options:
# id_prefix: the prefix of the id attributes.
# current: the id of the current tab
# tabs: array of tab ids (in order to display them)
# labels: maps tab ids to DOM labels for each tab.
# links: maps tab ids to the URL for each view if there is no javascript.
# [icons]: maps tab ids to DOM containing a related icon
# [slow_tabs]: optional array of tabs which must always be linked
#  slowly rather than using javascript.
#
######################################################################

sub render_tabs
{
	my( $self, %params ) = @_;

	my $tabs = $params{tabs};
	my $current = $params{current} || $tabs->[0];
	my $labels = $params{labels};
	my %expensive = map { $_ => 1 } @{$params{slow_tabs}||[]};

	# TODO support $params{icons}, $params{links}
	return $self->xhtml->tabs(
		[@{$labels}{@$tabs}],
		[],
		basename => $params{id_prefix},
		expensive => [grep { $expensive{$tabs->[$_]} } 0..$#$tabs],
		current => (grep { $tabs->[$_] eq $current } 0..$#$tabs)[0],
		aliases => { map { $_ => $tabs->[$_] } 0..$#$tabs },
		links => $params{links},
		icons => $params{icons},
	);
}

######################################################################
# 
# $id = $repository->get_next_id
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












#############################################################
#############################################################
=pod

=begin InternalDoc

=back

=head2 Methods relating to the current XHTML page

=over 4

=end InternalDoc

=cut
#############################################################
#############################################################

######################################################################
=pod

=begin InternalDoc

=item $repository->write_static_page( $filebase, $parts, [$page_id], [$wrote_files] )

Write an .html file plus a set of files describing the parts of the
page for use with the dynamic template option.

File base is the name of the page without the .html suffix.

parts is a reference to a hash containing DOM trees.

If $wrote_files is defined then any filenames written are logged in it as keys.

=end InternalDoc

=cut
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
		next if !defined $parts->{$part_id};
		if( !ref($parts->{$part_id}) )
		{
			EPrints::abort( "Page parts must be DOM fragments" );
		}
		my $file = $filebase.".".$part_id;
		if( open( CACHE, ">$file" ) )
		{
			binmode(CACHE,":utf8");
			print CACHE $self->xhtml->to_xhtml( $parts->{$part_id} );
			close CACHE;
			if( defined $wrote_files )
			{
				$wrote_files->{$file} = 1;
			}
		}
		else
		{
			$self->log( "Could not write to file $file" );
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
		$self->log( "Could not write to file $title_textonly_file" );
	}

	my $html_file = $filebase.".html";
	$self->prepare_page( $parts, page_id=>$page_id );
	$self->page_to_file( $html_file, $wrote_files );
}

######################################################################
=pod

=begin InternalDoc

=item $repository->prepare_page( $parts, %options )

Create an XHTML page for this session. 

$parts is a hash of XHTML elements to insert into the pins in the
template. Usually: title, page. Maybe pagetop and head.

If template is set then an alternate template file is used.

This function only builds the page it does not output it any way, see
the methods below for that.

Options include:

page_id=>"id to put in body tag"
template=>"The template to use instead of default."

=end InternalDoc

=cut
######################################################################
# move to compat module?

sub build_page
{
	my( $self, $title, $mainbit, $page_id, $links, $template ) = @_;
	$self->prepare_page( { title=>$title, page=>$mainbit, pagetop=>undef,head=>$links}, page_id=>$page_id, template=>$template );
}
sub prepare_page
{
	my( $self, $map, %options ) = @_;
	$self->{page} = $self->xhtml->page( $map, %options );
}


######################################################################
=pod

=begin InternalDoc

=item $repository->send_page( %httpopts )

Send a web page out by HTTP. Only relevant if this is a CGI script.
build_page must have been called first.

See send_http_header for an explanation of %httpopts

Dispose of the XML once it's sent out.

=end InternalDoc

=cut
######################################################################

sub send_page
{
	my( $self, %httpopts ) = @_;

	$self->{page}->send( %httpopts );
	delete $self->{page};
}


######################################################################
=pod

=begin InternalDoc

=item $repository->page_to_file( $filename, [$wrote_files] )

Write out the current webpage to the given filename.

build_page must have been called first.

Dispose of the XML once it's sent out.

If $wrote_files is set then keys are created in it for each file
created.

=end InternalDoc

=cut
######################################################################

sub page_to_file
{
	my( $self , $filename, $wrote_files ) = @_;
	
	$self->{page}->write_to_file( $filename, $wrote_files );
	delete $self->{page};
}

######################################################################
=pod

=begin InternalDoc

=item $repository->set_page( $newhtml )

Erase the current page for this session, if any, and replace it with
the XML DOM structure described by $newhtml.

This page is what is output by page_to_file or send_page.

$newhtml is a normal DOM Element, not a document object.

=end InternalDoc

=cut
######################################################################

sub set_page
{
	my( $self, $newhtml ) = @_;
	
	$self->{page} = EPrints::Page::DOM->new( $self, $newhtml );
}


######################################################################
=pod

=begin InternalDoc

=item $copy_of_node = $repository->clone_for_me( $node, [$deep] )

XML DOM items can only be added to the document which they belong to.

A EPrints::Repository has it's own XML DOM DOcument. 

This method copies an XML node from _any_ document. The copy belongs
to this sessions document.

If $deep is set then the children, (and their children etc.), are 
copied too.

=end InternalDoc

=cut
######################################################################

sub clone_for_me
{
	my( $self, $node, $deep ) = @_;

	return $self->xml->clone( $node ) if $deep;

	return $self->xml->clone_node( $node );
}


######################################################################
=pod

=begin InternalDoc

=item $repository->redirect( $url, [%opts] )

Redirects the browser to $url.

Optional argument $opts{status_code} to specify the returned HTTP status code:

    value  HTTP Status
    301    301 Moved Permanently
    302    302 Found
    303    303 See Other
    307    307 Temporary Redirect
    308    308 Permanent Redirect  (experimental)

By default 302 temporary redirection is issued.

=end InternalDoc

=cut
######################################################################

sub redirect
{
	my( $self, $url, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( !$self->is_online )
	{
		print STDERR "ODD! redirect called in offline script.\n";
		return;
	}

	my $status = delete $opts{status_code} || 302;
	
	EPrints::Apache::AnApache::send_status_line( $self->request, $status );
	EPrints::Apache::AnApache::header_out( 
		$self->request,
		"Location",
		$url );

	EPrints::Apache::AnApache::send_http_header( $self->request, %opts );

	return $status;
}

######################################################################
=pod

=begin InternalDoc

=item $repository->not_found( [ $message ] )

Send a 404 Not Found header. If $message is undef sets message to
'Not Found' but does B<NOT> print an error message, otherwise
defaults to the normal 404 Not Found type response.

=end InternalDoc

=cut
######################################################################

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
	return 404;
}

######################################################################
=pod

=begin InternalDoc

=item $repository->send_http_header( %opts )

Send the HTTP header. Only makes sense if this is running as a CGI 
script.

Opts supported are:

content_type. Default value is "text/html; charset=UTF-8". This sets
the http content type header.

lang. If this is set then a cookie setting the language preference
is set in the http header.

=end InternalDoc

=cut
######################################################################

sub send_http_header
{
	my( $self, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{offline} )
	{
		$self->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	if( !defined $opts{content_type} )
	{
		$opts{content_type} = 'text/html; charset=utf-8';
	}
	$self->{request}->content_type( $opts{content_type} );

	EPrints::Apache::AnApache::header_out( 
		$self->{"request"},
		"Cache-Control" => "no-store, no-cache, must-revalidate" );

	EPrints::Apache::AnApache::send_http_header( $self->{request} );
}

# $repository->read_params
# 
# If we're online but have not yet read the CGI parameters then this
# will cause sesssion to read (and consume) them.

# If we're coming from cookie login page then grab the CGI params
# from an apache note set in Login.pm

sub read_params
{
	my( $self ) = @_;

	my $r = $self->{request};
	if( !$r )
	{
		EPrints::abort( "Attempt to read_params without a mod_perl request" );
	}

	my $uri = $r->unparsed_uri;
	my $progressid = ($uri =~ /progress_?id=([a-fA-F0-9]{32})/)[0];

	my $c = $r->connection;

	my $params = $c->notes->get( "loginparams" );
	if( defined $params && $params ne 'undef')
	{
 		$self->{query} = CGI->new( $r, $params ); 
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
			$self->{query} = CGI->new( $r );
		}
		else
		{
			$self->{query} = CGI->new( $r, \&EPrints::DataObj::UploadProgress::update_cb, $progress );

			# The CGI callback doesn't include the rest of the POST that
			# Content-Length includes
			$progress->set_value( "received", $size );
			$progress->commit;
		}
	}
	else
	{
 		$self->{query} = CGI->new( $r );
	}

	$c->notes->set( loginparams=>'undef' );
}

######################################################################
=pod

=begin InternalDoc

=item $bool = $repository->have_parameters

Return true if the current script had any parameters (post or get)

=end InternalDoc

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

	my $user = EPrints::DataObj::User::user_with_username( $self, $username );
	return $user;
}

sub current_loginticket
{
	my( $self ) = @_;

	return EPrints::DataObj::LoginTicket->new_from_request(
		$self,
		$self->{request}
	);
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
		my $user = EPrints::DataObj::User->new( $self, $userid );
		return $user;
	}
	
	my $ticket = $self->current_loginticket;
	return undef if !defined $ticket;

	$ticket->update;

	return $self->user( $ticket->value( "userid" ) );
}

######################################################################
=pod

=begin InternalDoc

=item $boolean = $repository->internal_button_pressed( $buttonid )

Return true if a button has been pressed in a form which is intended
to reload the current page with some change.

Examples include the "more spaces" button on multiple fields, the 
"lookup" button on succeeds, etc.

=end InternalDoc

=cut
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


######################################################################
=pod

=begin InternalDoc

=item $action_id = $repository->get_action_button

Return the ID of the eprint action button which has been pressed in
a form, if there was one. The name of the button is "_action_" 
followed by the id. 

This also handles the .x and .y inserted in image submit.

This is designed to get back the name of an action button created
by render_action_buttons.

=end InternalDoc

=cut
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



######################################################################
=pod

=begin InternalDoc

=item $button_id = $repository->get_internal_button

Return the id of the internal button which has been pushed, or 
undef if one wasn't.

=end InternalDoc

=cut
######################################################################

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

=begin InternalDoc

=item $status = $repository->get_http_status

Return the status of the current HTTP request.

=end InternalDoc

=cut
######################################################################

sub get_http_status
{
	my( $self ) = @_;

	return $self->{request}->status();
}







#############################################################
#############################################################
=pod

=begin InternalDoc

=back

=head2 Methods related to Plugins

=over 4

=end InternalDoc

=cut
#############################################################
#############################################################


######################################################################
=pod

=begin InternalDoc

=item $plugin = $repository->plugin( $pluginid )

Return the plugin with the given pluginid, in this repository or, failing
that, from the system level plugins.

=end InternalDoc

=cut
######################################################################

sub plugin
{
	my( $self, $pluginid, %params ) = @_;

	return $self->get_repository->get_plugin_factory->get_plugin( $pluginid,
		%params,
		session => $self,
		repository => $self,
		);
}

=begin InternalDoc

=item $success = $repository->expire_abstracts()

Cause the abstract pages to regenerate next time they are requested by expiring them.

Returns success if done successfully.

=end InternalDoc

=cut

sub expire_abstracts
{
	my ( $self ) = @_;

	my $file = $self->get_conf( "variables_path" )."/abstracts.timestamp";
	
	unless( open( CHANGEDFILE, ">$file" ) )
	{
		return 0;
	}
	
	print CHANGEDFILE "This file last poked at: ".EPrints::Time::human_time()."\n";
	close CHANGEDFILE;

	return 1;
}



######################################################################
=pod

=begin InternalDoc

=item @plugin_ids  = $repository->plugin_list( %restrictions )

Return either a list of all the plugins available to this repository or
return a list of available plugins which can accept the given 
restrictions.

Restictions:
 vary depending on the type of the plugin.

=end InternalDoc

=cut
######################################################################

sub plugin_list
{
	my( $self, %restrictions ) = @_;

	return
		map { $_->get_id() }
		$self->get_plugin_factory->get_plugins(
			{ session => $self },
			%restrictions,
		);
}

=begin InternalDoc

=item @plugins = $repository->get_plugins( [ $params, ] %restrictions )

Returns a list of plugin objects that conform to %restrictions (may be empty).

If $params is given uses that hash reference to initialise the plugins. Always passes this session to the plugin constructor method.

=end InternalDoc

=cut

sub get_plugins
{
	my( $self, @opts ) = @_;

	my $params = scalar(@opts) % 2 ?
		shift(@opts) :
		{};

	$params->{repository} = $params->{session} = $self;

	return $self->get_plugin_factory->get_plugins( $params, @opts );
}



#############################################################
#############################################################
=pod

=back

=begin InternalDoc

=head2 Other Methods

=end InternalDoc

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=begin InternalDoc

=item $foo = $repository->mail_administrator( $subjectid, $messageid, %inserts )

Sends a mail to the repository administrator with the given subject and
message body.

$subjectid is the name of a phrase in the phrase file to use
for the subject.

$messageid is the name of a phrase in the phrase file to use as the
basis for the mail body.

%inserts is a hash. The keys are the pins in the messageid phrase and
the values the utf8 strings to replace the pins with.

=end InternalDoc

=cut
######################################################################

sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	
	# Mail the admin in the default language
	my $langid = $self->get_conf( "defaultlanguage" );
	return EPrints::Email::send_mail(
		session => $self,
		langid => $langid,
		to_email => $self->get_conf( "adminemail" ),
		to_name => $self->phrase( "lib/session:archive_admin" ),	
		from_email => $self->get_conf( "adminemail" ),
		from_name => $self->phrase( "lib/session:archive_admin" ),	
		subject =>  EPrints::Utils::tree_to_utf8(
			$self->html_phrase( $subjectid ) ),
		message => $self->html_phrase( $messageid, %inserts ) );
}



my $PUBLIC_PRIVS =
{
	"eprint_search" => 1,
	"eprint/archive/view" => 1,
	"eprint/archive/export" => 1,
	"subject/view" => 1,
	"subject/export" => 1,
	"saved_search/public_saved_search/export" => 1,
	"saved_search/public_saved_search/view" => 1,
};

sub allow_anybody
{
	my( $repository, $priv ) = @_;

	return 1 if( $PUBLIC_PRIVS->{$priv} );

	# This doesn't understand actual roles, just +priv 
	# we might extend it later if there's a need. 
	my $public_roles = $repository->config( "public_roles" );
	if( $public_roles ) 
	{
		foreach my $role_id ( @{$public_roles} )
		{
			return 1 if( $role_id eq "+".$priv );
		}
	}

	return 0;
}



sub login
{
	my( $self,$user,$code ) = @_;
}

=begin InternalDoc

=item $real_username = $repository->valid_login( $username, $password )

If $username and $password are a valid user account returns the real username of the user account (which may differ from $username).

Returns undef if $username or $password are invalid.

=end InternalDoc

=cut

sub valid_login
{
	my( $self, $username, $password ) = @_;

	my $real_username;
	if( $self->can_call( "check_user_password" ) )
	{
		$real_username = $self->call( "check_user_password",
			$self,
			$username,
			$password
		);
		# check_user_password normally returns '1' or '0'
		if( defined $real_username )
		{
			if( $real_username eq "1" )
			{
				$real_username = $username;
			}
			elsif( $real_username eq "0" )
			{
				$real_username = undef;
			}
		}
	}
	else
	{
		$real_username = $self->get_database->valid_login( $username, $password );
	}

	return $real_username;
}

sub cache_subjects
{
  my( $self ) = @_;

  ( $self->{subject_cache}, $self->{subject_child_map} ) =
    EPrints::DataObj::Subject::get_all( $self );
    $self->{subjects_cached} = 1;
}


######################################################################
#
# $repository->get_static_page_conf_file
# 
# Utility method to return the config file for the static html page 
# being viewed, if there is one, and it's in the repository config.
#
######################################################################

sub get_static_page_conf_file
{
	my( $repository ) = @_;

	my $r = $repository->get_request;
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

	my $lang = EPrints::Repository::get_session_language( $repository, $r );
	my $args = $r->args;
	$args = "?$args" if defined $args;

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
		my $conffile = "lang/".$repository->get_langid."/static".$uri.".".$suffix;	
		if( -e $repository->get_repository->get_conf( "config_path" )."/".$conffile )
		{
			return $conffile;
		}
	}

	return undef;
}

sub check_last_changed
{
	my( $self ) = @_;

	my $file = $self->{config}->{variables_path}."/last_changed.timestamp";
	my $poketime = (stat( $file ))[9];
	# If the /cfg/.changed file was touched since the config
	# for this repository was loaded then we will reload it.
	# This is not as handy as it sounds as we'll have to reload
	# it each time the main server forks.
	if( defined($poketime) && $poketime > $self->{loadtime} )
	{
		print STDERR "$file has been modified since the repository config was loaded: reloading!\n";
		if( $self->load_config )
		{
			$self->{loadtime} = time();
		}
		else
		{
			warn( "Something went wrong while reloading configuration" );
		}
	}
}

sub check_developer_mode
{
	my( $self ) = @_;

	return if !-e $self->{config}->{variables_path}."/developer_mode_on";
	
	print STDERR $self->{id}." repository has developer mode switched on. The config will be reloaded every request and abstract pages will be generated on demand. Turn this off when you finish development\n";
	if( $self->load_config( 1 ) )
	{
		$self->{loadtime} = time();
	}
	else
	{
		warn( "Something went wrong while reloading configuration" );
	}

	my $file = $self->config( "variables_path" )."/abstracts.timestamp";

	unless( open( CHANGEDFILE, ">$file" ) )
	{
		EPrints::abort( "Cannot write to file $file" );
	}
	print CHANGEDFILE "This file last poked at: ".EPrints::Time::human_time()."\n";
	close CHANGEDFILE;
}

=item $repo->init_from_indexer( $daemon )

(Re)initialise the repository object for use by the indexer.

Calls L</check_last_changed>.

=cut

sub init_from_indexer
{
	my( $self ) = @_;

	# see if we need to reload our configuration
	$self->check_last_changed;

	# connect to the database
	$self->{database} = EPrints::Database->new( $self );

	# set the language to default
	$self->change_lang();
}

sub init_from_request
{
	my( $self, $request ) = @_;

	$self->{request} = $request;

	return if !$request->is_initial_req;

	# see if we need to reload our configuration
	$self->check_developer_mode;
	$self->check_last_changed;

	# go online
	$self->{request} = $request;
	$self->{offline} = 0;

	# register a cleanup call for us
	$request->pool->cleanup_register( \&cleanup, $self );

	# connect to the database
	$self->{database} = EPrints::Database->new( $self );

	if( !defined $self->{database} )
	{
		EPrints->abort( "Error connecting to database: ".$DBI::errstr );
	}

	# add live HTTP path configuration
	$self->_add_live_http_paths;

	# set the language for the current user
	$self->change_lang( $self->get_session_language( $request ) );
	
	$self->init_cache;

	$self->run_trigger( EP_TRIGGER_BEGIN_REQUEST );

	return 1;
}

my @CACHE_KEYS = qw/ id citations class config datasets field_defaults html_templates template_path langs plugins storage template_mtime text_templates types workflows loadtime noise /;
my %CACHED = map { $_ => 1 } @CACHE_KEYS;

sub cleanup
{
	my( $self ) = @_;

	if( $self->get_online )
	{
		$self->run_trigger( EP_TRIGGER_END_REQUEST )
	}

	if( defined $self->{database} )
	{
		$self->{database}->disconnect;
	}

	for(keys %$self)
	{
		delete $self->{$_} if !$CACHED{$_};
	}

	if( defined $self->{memd} )
	{
		$self->{memd}->disconnect_all;
	}

	$self->{offline} = 1;
}

######################################################################
=pod

=back

=cut

######################################################################



1;



=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

