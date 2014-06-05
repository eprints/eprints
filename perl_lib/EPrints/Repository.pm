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
#  $self->{online}
#     True if this is a Web request
#     False if this is a command-line script.
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
use CGI qw(-compile);

use strict;


######################################################################
=pod

=item $repository = EPrints::Repository->new( %opts )

Creates and returns a new repository object. This is a utility object only and
will only have the basic system configuration available.

=item $repository = EPrints::Repository->new( $repository_id, %opts )

Create a connection to an EPrints repository $repository_id which provides
access to the database and to the repository configuration.

Options:

	check_db - 1
	noise - 0

=cut
######################################################################

# opts:
#  consume_post (default 1), assumes cgi=1
#  cgi (default 0)
#  noise (default 0)
#  check_db (default 1)
#
sub new
{
	my $class = shift;

# TODO/sf2 - _new still used?
	if( @_ % 2 == 0 )
	{
		return $class->_new( @_ );
	}

	my( $repository_id, %opts ) = @_;

	my $debug = delete $opts{debug};

	EPrints::Utils::process_parameters( \%opts, {
		  consume_post => 1,
		         noise => 0,
		      check_db => 1,
	});

	my $self = bless {}, $class;

# TODO/sf2 - to totally disable the debug_log method?
# *debug_log = sub {};

	$self->{debug} = $debug;
	# ON by default:
	$self->{debug}->{$_} ||= 1 for(qw/ controllers crud auth security database / );	

	$self->{debug}->{$_} ||= 0 for(qw/ warnings db sql sql_prepare request controllers security auth memcached storage crud page /);

	
	$self->{noise} = $opts{noise};
	$self->{noise} = 0 if ( !defined $self->{noise} );

	$self->{used_phrases} = {};

	$self->{online} = 0;
	
	$self->{id} = $repository_id;

	$self->load_config();

	if( $self->{noise} >= 2 ) { print "\nStarting EPrints Repository.\n"; }

# TODO/sf2 - how can this be TRUE if {online} is set to FALSE a few lines above?
	if( $self->is_online )
	{
		# running as CGI, Lets work out what language the
		# client wants...
		$self->change_lang( get_session_language( 
			$self,
			$self->{request} ) );
	}
	else
	{
		# Set a script to use the default language unless it 
		# overrides it
		$self->change_lang( 
			$self->config( "defaultlanguage" ) );
	}
	
	$self->{check_db} = $opts{check_db};

	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
	if( $self->is_online && (!defined $opts{consume_post} || $opts{consume_post}) )
	{
		$self->read_params; 
	}

# sf2 - new: memcached init
	$self->init_cache;

	$self->call( "session_init", $self, !$self->is_online );

	$self->{loadtime} = time();
	
	return( $self );
}

# sf2 - new - init Memcached if enabled and available. 
# this allows server-wide caching of data (e.g. data-objects) 
sub init_cache
{
	my( $self ) = @_;

	# already initialised or not available
	return undef if( exists $self->{memd} || $self->{memd_disabled} );

	# perhaps caching is disabled - or the module isn't installed
	if( !$self->config( 'use_memcached' ) || !EPrints::Utils::require_if_exists( 'Cache::Memcached::Fast' ) )
	{
		$self->{memd_disabled} = 1;
		return undef;
	}

	# the config 'memcached' contains all the calling options of the module (max size etc)
	$self->{memd} = $self->config( 'memcached' );

	if( !defined $self->{memd} )
	{
		$self->log( "EPrints: failed to initialise memory caching." );
		$self->{memd_disabled} = 1;
		return undef;
	}

	my $n = 0;
	my $versions = $self->{memd}->server_versions;
		while (my ($server, $version) = each %$versions) {
			$self->debug_log( "memcached", "cache enabled on server: %s (v%s)\n", $server, $version );
			$n++;
	}
	
	if( $n == 0 )
	{
		$self->debug_log( "memcached", "no server available - caching disabled" );
		$self->{memd_disabled} = 1;
		delete $self->{memd};
		return undef;
	}

	delete $self->{memd_disabled};

	return 1;
}

# sf2 - new - store some cached data whose key is prefixed with the repository id
sub cache_set
{
	my( $self, $key, $value ) = @_;

	return undef if( $self->{memd_disabled} );
	
	$self->debug_log( "memcached", "setting '".$self->id.":$key' by %s",join(",",caller) );

	return $self->{memd}->set( $self->id.":".$key, $value );
}

# sf2 - new - retrieve some previously cached data
sub cache_get
{
	my( $self, $key ) = @_;

	return undef if( $self->{memd_disabled} );

	$self->debug_log( "memcached", "getting '".$self->id.":$key'" );

	return $self->{memd}->get( $self->id.":".$key );
}

# sf2 - new - remove some previously cached data
sub cache_remove
{
	my( $self, $key ) = @_;

	return undef if( $self->{memd_disabled} );

	# DEBUG
	# print STDERR 
	$self->debug_log( "memcached", "removing '".$self->id.":$key'" );

	return $self->{memd}->remove( $self->id.":".$key );
}

# sf2 - new - flush the entire cache
# TODO ought to be called when database is created, the data schema changes etc etc
sub cache_flush
{
	my( $self ) = @_;

	$self->{memd}->flush_all if( defined $self->{memd} );

	return;
}

sub _new
{
	my( $class, %opts ) = @_;

	my $self = bless {}, $class;

	EPrints->trace( "repo::_new called" );

	$self->{online} = 0;

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

	$self->_load_languages();
	$self->_load_storage();

	# memcached
	$self->init_cache;

	return;
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
	return;
}

######################################################################
=pod

=begin InternalDoc

=item $request = $repository->get_request;

Return the Apache request object (from mod_perl) or undefined if 
this isn't a CGI script.

=end InternalDoc

=cut
######################################################################

sub request { shift->get_request }
sub get_request
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

	return undef if !$self->is_online;

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
	return if $self->is_online;

	if( $self->database )
	{
		$self->database->disconnect();
	}

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
	
	return;
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
		$self->_load_namedsets() || return;
		$self->_load_datasets() || return;
		$self->_load_languages() || return;
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

	if( !-d $dir ) { EPrints->system->mkdir( $dir ); }
	if( !defined $parts->{template} && -e "$filebase.template" )
	{
		unlink( "$filebase.template" );
	}
	foreach my $part_id ( keys %{$parts} )
	{
		next if !defined $parts->{$part_id};
		if( !ref($parts->{$part_id}) )
		{
			EPrints->abort( "Page parts must be DOM fragments" );
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
	return;
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
	return;
}
sub prepare_page
{
	my( $self, $map, %options ) = @_;
	$self->{page} = $self->xhtml->page( $map, %options );
	return;
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
	return;
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
	return;
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
	return;
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
	return;
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

	my %info;

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

	foreach my $ds_id ( keys %info	)
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
		foreach my $field ($dataset->fields)
		{
			next unless $field->isa( "EPrints::MetaField::Counter" );
			my $c_id = $field->get_property( "sql_counter" );
			push @counter_ids, $c_id if defined $c_id;
		}
	}

	return @counter_ids;
}

sub has_dataset
{
	my( $self, $datasetid ) = @_;

	return 0 if( !$datasetid );

	return defined $self->{datasets}->{$datasetid};
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
	my( $self , $datasetdef ) = @_;

	my( $datasetid, $state ) = split( /\./, $datasetdef );

	my $context;

	if( defined $state )
	{
		( $state, $context ) = split( /:/, $state );
	}
	else
	{
		( $datasetid, $context ) = split( /:/, $datasetid );
	}

# sf2 - important: DataSet objects used to be passed as a copy of the 
# object stored in Repository.pm
# however since that object is shared by any processes requesting $repo->dataset( '..')
# (within the same web request/CLI process) then the object might get 'dirty' 
# (e.g. one process might set the 'state' and the other processes might set another 'state')
#
# so at the moment, DataSets objects are re-created basically so that each process
# get a fresh object
#
#
# TODO this ^^ can be optimised e.g. DataSets don't really need to
# reload all their conf? can't we also just copy/clone the object
# we have in $repo->{datasets} ? would be nice...
#


#	my $ds_conf = $self->config( 'datasets', $datasetid );
#
#	my $ds = EPrints::DataSet->new( 
#			repository => $self,
#			name => $datasetid,
#			%{$ds_conf ||{}}
#	);			
#

	my $ds = $self->{datasets}->{$datasetid};

	if( !defined $ds )
	{
		# $self->log( "Unknown dataset: %s", $datasetid );
		EPrints->trace( "Unknown dataset '$datasetid'" );
		return undef;
	}

	$ds->reset_state;
	$ds->reset_context;
#
# TODO ^^^ is that ok?
#
## that'd be bad
#if( defined ( my $state = $ds->state ) )
#{
#	printf STDERR "Warning: ds '%s' in state %s", "$ds", $state;
#}
	if( defined $state )
	{
		return undef if( !$ds->set_state( $state ) );
	}

## TODO
#
# problem: this consumes POST-data!! so can't be a query param... tho higher level API (CRUD, Search) may
#		parse some custom "context" query param and apply it to the dataset if they wish...
#
	if( defined $context )
	{
		return undef if( !$ds->is_valid_context( $context ) );
		$self->debug_log( "security", "forcing context %s on dataset %s", $context, $ds->id );
		$ds->set_context( $context );
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

sub get_conf 
{
	EPrints->trace( "Repository::get_conf is deprecated" );

	return config( @_ ); 
}

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

	return $rc;
}

# TODO/sf2 - temp method whilst dev - might keep it though if useful
sub debug_log
{
	my( $self, @args ) = @_;

	my $type = shift @args;

	if( $self->{debug}->{$type} )
	{
		$args[0] = sprintf "[%s] %s", $type, $args[0];
		$self->log( @args ) 
	}
	return;
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
	my( $self, $msg, @args ) = @_;

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
		$self->call( 'log', $self, sprintf $msg, @args );
	}
	else
	{
		chomp $msg;
		printf STDERR "$msg\n", @args;
	}
	return;
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
	return $dirs[-1] if $self->config( "disable_df" );

	my $root = $self->config( "documents_path" );

	my $warnsize = $self->config( "diskspace_warn_threshold" );
	my $errorsize = $self->config( "diskspace_error_threshold" );

	my $warn = 1;
	my $error = 1;

	my %space;
	foreach my $dir (@dirs)
	{
		my $space = EPrints->system->free_space( "$root/$dir" );
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
	return $dirs[-1];
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

	my $theme = $self->config( "ui", "theme" );
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
# 
# $success = $repository_config->_load_templates
#
# Loads and caches all the html template files for this repository.
#
######################################################################

sub _load_templates
{
	my( $self ) = @_;

	$self->debug_log( "ui", "loading templtes" );

	# sf2
	$self->{templates} ||= {};

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

				my $path = "$dir/$fn";
				$self->{templates}->{$id} ||= {};
				my $template = $self->{templates}->{$id}->{$langid};
				if( !$template )
				{
					$template = $self->{templates}->{$id}->{$langid} = 
						EPrints::XHTML::Template->new( path => $path, repository => $self, langid => $langid );

					$self->debug_log( "ui", "loaded template '%s' (%s)", $id, $langid );

					if( !$template )
					{
						$self->log( "Failed to load template %s", $path );
					}
					# sf2? ->refresh?
				}
					
				$template->refresh;
			}
			closedir( $dh );
		}
	# sf2 - ignore that error - UI not compulsory?
	#	if( !defined $self->{html_templates}->{default}->{$langid} )
	#	{
	#		EPrints::abort( "Failed to load default template for language $langid" );
	#	}
	}

	return 1;
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

sub get_template { return template( @_ ) } 
sub template
{
	my( $self, $langid, $id ) = @_;

	$langid ||= $self->get_langid;
	$id ||= 'default';  

	my $template = $self->{templates}->{$id}->{$langid};
	if( !defined $template ) 
	{
		EPrints::abort( <<END );
Error. Template not loaded.
Language: $langid
Template ID: $id
END
	}

	$template->refresh;

	return $template;
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

	return EPrints->system->free_space( $filepath );
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
	return;
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

	my $cookie = EPrints::Apache::cookie( 
		$request,
		"eprints_lang" );
	push @prefs, $cookie if defined $cookie;

	# then look at the accept language header
	my $accept_language = EPrints::Apache::header_in( 
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
	push @prefs, $repository->config( "defaultlanguage" );

	# So, which one to use....
	my $arc_langs = $repository->config( "languages" );	
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
		$newlangid = $self->config( "defaultlanguage" );
	}
	$self->{lang} = $self->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
	return;
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
		$inserts{$_} = $self->xml->create_text_node( $inserts{$_} );
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
	my $defaultlangid = $repository->config( "defaultlanguage" );
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

=item $db = $repository->get_database

Return the current EPrints::Database connection object.

=end InternalDoc

=cut
######################################################################
sub get_db { shift->database( @_ ); } # back compatibility

sub get_database { shift->database( @_ ) }
sub database
{
	my( $self ) = @_;

	if( $self->{database} )
	{
		# already connected
		return $self->{database};
	}

	if( $self->{database_failed} )
	{
		# don't re-attempt to connect if this has failed already
		return undef;
	}
	
	# connect to the DB
	$self->{database} = EPrints::Database->new( $self );

	if( $self->{database} )
	{
		#cjg make this a method of EPrints::Database?
		if( !defined $self->{check_db} || $self->{check_db} )
		{
			# Check there are some tables.
			# Well, check for the most important table, which 
			# if it's not there is a show stopper.
			unless( $self->{database}->is_latest_version )
			{ 
				my $cur_version = $self->{database}->get_version || "unknown";
				if( $self->database->has_table( "user" ) )
				{	
					EPrints->abort(
		"Database tables are in old configuration (version $cur_version). Please run:\nepadmin upgrade ".$self->get_id );
				}
				else
				{
					EPrints->abort(
						"No tables in the MySQL database! ".
						"Did you run create_tables?" );
				}
				$self->{database}->disconnect();
				return undef;
			}
		}

		delete $self->{database_failed};	# to be safe
		return $self->{database};
	}

	$self->log( $self->phrase( "lib/session:fail_db_connect" ) );
	# it failed
	$self->{database_failed} = 1;
	EPrints->trace;

	return undef;
}

# check if we're connected to the DB
sub database_connected
{
	my( $self ) = @_;

	return defined $self->{database};
}

# sf2 - new - TODO name confusing with the above method
sub connect_database
{
	return ( shift->database ? 1 : 0 );
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

# sf2 - deprecated get_repository
sub get_repository
{
	my( $self ) = @_;

        EPrints->trace( "Repository::get_repository (deprecated)" );

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

# sf2 - depr
sub get_online
{
	my( $self ) = @_;
	
	EPrints->trace( "Repository::get_online is deprecated" );

	return $self->is_online;
}

sub is_online 
{ 
	return shift->{online};
}

######################################################################
=pod

=begin InternalDoc

=item $secure = $repository->is_secure

Returns true if we're using HTTPS/SSL (checks get_online first).

=end InternalDoc

=cut
######################################################################

# sf2 - depr
sub get_secure
{
	my( $self ) = @_;

	EPrints->trace( "Repository::get_secure is deprecated" );

	return $self->is_secure;
}

sub is_secure
{
	my( $self ) = @_;

	# mod_ssl sets "HTTPS", but only AFTER the Auth stage
	return $self->is_online &&
		($ENV{"HTTPS"} || $self->request->dir_config( 'EPrints_Secure' ));
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

# sf2 - TODO - needed?
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

# TODO sf2 - move to $self->xml
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

=end InternalDoc

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
	EPrints::Apache::send_status_line( $self->{"request"}, 302, "Moved" );
	EPrints::Apache::header_out( 
		$self->{"request"},
		"Location",
		$url );

	return 302;
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

	EPrints::Apache::send_status_line( $self->{"request"}, 404, $message );
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
	if( !$self->is_online )
	{
		$self->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	if( !defined $opts{content_type} )
	{
		$opts{content_type} = 'text/html; charset=utf-8';
	}
	$self->{request}->content_type( $opts{content_type} );

	EPrints::Apache::header_out( 
		$self->{"request"},
		"Cache-Control" => "no-store, no-cache, must-revalidate" );
	return;

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
		EPrints->abort( "Attempt to read_params without a mod_perl request" );
	}

	$self->debug_log( "request", "consuming POSTDATA" );

	my $uri = $r->unparsed_uri;

# TODO sf2 - remove that:
	my $progressid = ($uri =~ /progress_?id=([a-fA-F0-9]{32})/)[0];

	my $c = $r->connection;

	my $params = $c->notes->get( "loginparams" );
	if( defined $params && $params ne 'undef')
	{
 		$self->{query} = CGI->new( $r, $params ); 
	}
	elsif( defined( $progressid ) && $r->method eq "POST" )
	{
# TODO sf2 - remove that - move to a Controller or something (all the upload progress stuff that is)
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
	return;
}


######################################################################
=pod

=begin InternalDoc

=item $bool = $repository->have_parameters

Return true if the current script had any parameters (post or get)

=end InternalDoc

=cut
######################################################################

# sf2 - needed? have_parameters should be has_params ?
sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->param();

	return( scalar @names > 0 );
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

	return $self->get_plugin_factory->get_plugin( $pluginid,
		%params,
		session => $self,
		repository => $self,
		);
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

# sf2 - TODO move to $self->email->... ? odd method to have in $repository
sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	
	# Mail the admin in the default language
	my $langid = $self->config( "defaultlanguage" );
	return EPrints::Email::send_mail(
		session => $self,
		langid => $langid,
		to_email => $self->config( "adminemail" ),
		to_name => $self->phrase( "lib/session:archive_admin" ),	
		from_email => $self->config( "adminemail" ),
		from_name => $self->phrase( "lib/session:archive_admin" ),	
		subject =>  EPrints::Utils::tree_to_utf8(
			$self->html_phrase( $subjectid ) ),
		message => $self->html_phrase( $messageid, %inserts ) );
}


sub allow_anybody
{
	my( $self, $priv ) = @_;

	EPrints->deprecated;
	
	return 0 if( !defined $priv );

	if( $self->{config}->{public_privs}->{$priv} )
	{
		if( $priv =~ /^acl\// )
		{
			$self->log( 'Repository->allow_anybody: not allowing "acl" dataset to be publicly accessible' );
			return 0;
		}

		return 1;
	}

	return 0;
}


# this is done via a Cookie and should only be called internally by $self->current_user
sub load_user_session
{
	my( $self ) = @_;

	$self->debug_log( "auth", "loading user session..." );

        my $ticket = EPrints::DataObj::LoginTicket->new_from_request( $self );

        if( !defined $ticket )
        {
		$self->debug_log( "auth", "loading user session failed" );
		return undef;
        }

        $ticket->update;

        my $user = $self->dataset( 'user' )->dataobj( $ticket->value( 'userid' ) );

        if( !defined $user )
        {
		$self->debug_log( "auth", "ticket found but user does not exist" );
                # invalid ticket
                $ticket->remove;
		return undef;
        }
        
	$self->debug_log( "auth", "loaded session for user '%s'", $user->value( 'username' ) );
       
	return $user;
}

# checks username, password OK against configured login method (internal, ldap...)
# creates ticket/user session
sub login
{
	my( $self, $username, $password ) = @_;

	# checks credentials are OK (internal, LDAP, ...)

	$username = $self->valid_login( $username, $password );

	if( defined $username )
	{
		my $user = EPrints::DataObj::User::user_with_username( $self, $username );
		if( defined $user )
		{
			$self->request->user( $username );

# TODO should clean up any tickets matching that userid and IP? 
# otherwise ppl authenticating with basic auth might create lots of tickets if they can't 
# store cookies eg curl (one per request)
			$self->dataset( "loginticket" )->create_dataobj({
				userid => $user->id,
			})->set_cookies();		

			$self->load_current_user( $user );
			
			$self->debug_log( "auth", "login OK - user session created, cookies sent" );

			return 1;
		}
	}

	return 0;
}

######################################################################
=pod

=item $user = $repository->current_user

Return the current logged in L<EPrints::DataObj::User> for this session.

Return undef if there isn't one.

=cut
######################################################################

sub set_cli_user
{
	my( $self, $user ) = @_;

	return if $self->is_online || !defined $user;

	$self->debug_log( "auth", "setting CLI user %s", $user->value( 'username' ) );

	$self->{current_user} = $user;
}

# allow to test whether there's a user already-logged in, without loading 
# a user-session when it's not
sub has_current_user
{
	my( $self ) = @_;

	return defined $self->{current_user};
}

sub current_user
{
	my( $self ) = @_;

	# we just logged out: (TODO is this actually used?)
	return undef if( $self->{logged_out} );
	
	if( !$self->is_online )
	{
		# allow a script to set a running user
		return $self->{current_user} if( defined $self->{current_user} );
		return undef;
	}

	# but for everything afterwards (cookie etc) we need the web
	
	if( defined $self->{current_user} )
	{
		return $self->{current_user};
	}

	my $user = $self->load_user_session();

	$self->{current_user} = $user;

	return $self->{current_user};

}

# sf2 - used anywhere?
sub logout
{
	my( $self ) = @_;
        
	my $ticket = EPrints::DataObj::LoginTicket->new_from_request( $self );

	if( $ticket )
	{
		$self->{logged_out} = 1;
		$ticket->remove;
		delete $self->{current_user};
	}

	return 1;
}

# sf2 - added - used by AUTH triggers to load the authenticated user
sub load_current_user
{
	my( $self, $user ) = @_;

	$self->{current_user} = $user;

	return;
}

sub reload_current_user
{
	my( $self ) = @_;

	delete $self->{current_user};
	return;
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
	return;
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
	return;
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

	$self->connect_database;

	# set the language to default
	$self->change_lang();
	return;
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
	$self->{online} = 1;

	# register a cleanup call for us
	$request->pool->cleanup_register( \&cleanup, $self );

	# Note that the connection to the DB is not initialised here - we'll connect on-demand

	# add live HTTP path configuration
	$self->_add_live_http_paths;

	# set the language for the current user
	$self->change_lang( $self->get_session_language( $request ) );

	$self->run_trigger( EP_TRIGGER_BEGIN_REQUEST );

	# memcached
	$self->init_cache;

	return 1;
}

my @CACHE_KEYS = qw/ id citations class config datasets field_defaults langs plugins storage types workflows loadtime noise templates memd debug /;
my %CACHED = map { $_ => 1 } @CACHE_KEYS;

sub cleanup
{
	my( $self ) = @_;
	
	if( $self->is_online )
	{
		$self->run_trigger( EP_TRIGGER_END_REQUEST )
	}

	if( $self->database_connected )
	{
		$self->debug_log( "db", "disconnecting" );
		$self->database->disconnect;
	}

#	if( defined $self->{memd} )
#	{
#		$self->debug_log( "memcached", "disconnecting" );
#		$self->{memd}->disconnect_all;
#	}

	for(keys %$self)
	{
		delete $self->{$_} if !$CACHED{$_};
	}

	foreach my $ds ( values %{ $self->{datasets} || {} } )
	{
		$ds->reset_state;
		$ds->reset_context;
	}


	$self->{online} = 0;
	return;
}

######################################################################
=pod

=back

=cut

######################################################################

# sf2 - deprecated
sub make_text
{
	my( $self, $value ) = @_;

	EPrints->deprecated();

	print STDERR "[make_text] $value\n";

	return $self->xml->create_text_node( $value );
}


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

