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

=over 4

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

use Unicode::String qw(utf8 latin1);

#use URI::Escape;
use CGI qw(-compile);

use strict;
#require 'sys/syscall.ph';



######################################################################
=pod

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
		if( $mode == 0 ) { $self->read_params; }
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
	if( $self->{noise} >= 2 ) { print "done.\n"; }
	
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

=item $request = $session->get_request;

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

=item $query = $session->get_query;

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

=item $session->terminate

Perform any cleaning up necessary, for example SQL cache tables which
are no longer needed.

=cut
######################################################################

sub terminate
{
	my( $self ) = @_;
	
	
	$self->{database}->garbage_collect();
	$self->{repository}->call( "session_close", $self );
	$self->{database}->disconnect();

	# If we've not printed the XML page, we need to dispose of
	# it now.
	EPrints::XML::dispose( $self->{doc} );

	if( $self->{noise} >= 2 ) { print "Ending EPrints Session.\n\n"; }

	# give garbage collection a hand.
	foreach( keys %{$self} ) { delete $self->{$_}; } 
}



#############################################################
#############################################################
=pod

=back

=head2 Language Related Methods

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $langid = EPrints::Session::get_session_language( $repository, $request )

Given an repository object and a Apache (mod_perl) request object, this
method decides what language the session should be.

First it looks at the HTTP cookie "eprints_lang", failing that it
looks at the prefered language of the request from the HTTP header,
failing that it looks at the default language for the repository.

The language ID it returns is the highest on the list that the given
eprint repository actually supports.

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

=item $session->change_lang( $newlangid )

Change the current language of the session. $newlangid should be a
valid country code for the current repository.

An invalid code will cause eprints to terminate with an error.

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

=item $xhtml_phrase = $session->html_phrase( $phraseid, %inserts )

Return an XHTML DOM object describing a phrase from the phrase files.

$phraseid is the id of the phrase to return. If the same ID appears
in both the repository-specific phrases file and the system phrases file
then the repository-specific one is used.

If the phrase contains <ep:pin> elements, then each one should have
an entry in %inserts where the key is the "ref" of the pin and the
value is an XHTML DOM object describing what the pin should be 
replaced with.

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

=item $utf8_text = $session->phrase( $phraseid, %inserts )

Performs the same function as html_phrase, but returns plain text.

All HTML elements will be removed, <br> and <p> will be converted 
into breaks in the text. <img> tags will be replaced with their 
"alt" values.

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

=item $language = $session->get_lang

Return the EPrints::Language object for this sessions current 
language.

=cut
######################################################################

sub get_lang
{
	my( $self ) = @_;

	return $self->{lang};
}


######################################################################
=pod

=item $langid = $session->get_langid

Return the ID code of the current language of this session.

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

=item $value = EPrints::Session::best_language( $repository, $lang, %values )

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

=item $viewname = $session->get_view_name( $dataset, $viewid )

Return a UTF8 encoded string containing the human readable name
of the /view/ section with the ID $viewid.

=cut
######################################################################

sub get_view_name
{
	my( $self, $dataset, $viewid ) = @_;

        return $self->phrase( 
		"viewname_".$dataset->confid()."_".$viewid );
}




#############################################################
#############################################################
=pod

=back

=head2 Accessor Methods

=over 4

=cut
#############################################################
#############################################################


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



######################################################################
=pod

=item $repository = $session->get_repository

Return the EPrints::Repository object associated with the Session.

=cut
######################################################################
sub get_archive { return $_[0]->get_repository; }

sub get_repository
{
	my( $self ) = @_;
	return $self->{repository};
}

######################################################################
=pod

=item $url = $session->get_url( [ %OPTS ] )

Utility method to get various URLs. See L<EPrints::URL>. With no arguments returns the same as get_uri().

	# Return the current static path
	$session->get_url( path => "static" );
	# Return the current cgi path
	$session->get_url( path => "cgi" );
	# Return a full URL to the current cgi path
	$session->get_url( host => 1, path => "cgi" );
	# Return a full URL to the static path under HTTP
	$session->get_url( scheme => "http", host => 1, path => "static" );

=cut
######################################################################

sub get_url
{
	my( $self, %opts ) = @_;

	my $url = EPrints::URL->new( session => $self );

	return $url->get( %opts );
}

######################################################################
=pod

=item $uri = $session->get_uri

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

=item $uri = $session->get_full_url

Returns the URL of the current script plus the CGI params.

=cut
######################################################################

sub get_full_url
{
	my( $self ) = @_;

	return undef unless defined $self->{request};


	my @params = $self->param;
	my $host = $self->{repository}->get_conf( "host" );
	my $port = $self->{repository}->get_conf( "port" );
	my $url = "http://$host".($port!=80?":$port":"").$self->{"request"}->uri;
	if( scalar @params == 0 )
	{
		return $url;
	}
	my @param_list = ();
	foreach my $param ( @params )
	{
		my $value = $self->param( $param );
		$param =~ s/([^a-zA-Z0-9])/sprintf( "%%%02X", ord( $1 ) )/eg;
		$value =~ s/([^a-zA-Z0-9])/sprintf( "%%%02X", ord( $1 ) )/eg;
		push @param_list, $param."=".$value;
	}

	return $url."?".join( "&", @param_list );
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

=item $secure = $session->get_secure

Returns true if we're using HTTPS/SSL (checks get_online first).

=cut
######################################################################

sub get_secure
{
	my( $self ) = @_;

	return $self->get_online && $ENV{"HTTPS"};
# There's also this variable defined by EPrints, but the HTTPS environment
# variable is the official way to know if we're running secure.
#	my $esec = $self->get_request->dir_config( "EPrints_Secure" );
}



#############################################################
#############################################################
=pod

=back

=head2 DOM Related Methods

These methods help build XML. Usually, but not always XHTML.

=over 4

=cut
#############################################################
#############################################################


######################################################################
=pod

=item $dom = $session->make_element( $element_name, %attribs )

Return a DOM element with name ename and the specified attributes.

eg. $session->make_element( "img", src => "/foo.gif", alt => "my pic" )

Will return the DOM object describing:

<img src="/foo.gif" alt="my pic" />

Note that in the call we use "=>" not "=".

=cut
######################################################################

sub make_element
{
	my( $self , $ename , %attribs ) = @_;

	my $element = $self->{doc}->createElement( $ename );
	foreach my $attr_name ( keys %attribs )
	{
		next unless( defined $attribs{$attr_name} );
		my $value = "$attribs{$attr_name}"; # ensure it's just a string
		$element->setAttribute( $attr_name , $value );
	}

	return $element;
}


######################################################################
=pod

=item $dom = $session->make_indent( $width )

Return a DOM object describing a C.R. and then $width spaces. This
is used to make nice looking XML for things like the OAI interface.

=cut
######################################################################

sub make_indent
{
	my( $self, $width ) = @_;

	return $self->{doc}->createTextNode( "\n"." "x$width );
}

######################################################################
=pod

=item $dom = $session->make_comment( $text )

Return a DOM object describing a comment containing $text.

eg.

<!-- this is a comment -->

=cut
######################################################################

sub make_comment
{
	my( $self, $text ) = @_;

	return $self->{doc}->createComment( $text );
}
	

# $text is a UTF8 String!

######################################################################
=pod

=item $DOM = $session->make_text( $text )

Return a DOM object containing the given text. $text should be
UTF-8 encoded.

Characters will be treated as _text_ including < > etc.

eg.

$session->make_text( "This is <b> an example" );

Would return a DOM object representing the XML:

"This is &lt;b&gt; an example"

=cut
######################################################################

sub make_text
{
	my( $self , $text ) = @_;

	# patch up an issue with Unicode::String containing
	# an empty string -> seems to upset XML::GDOME
	if( !defined $text || $text eq "" )
	{
		$text = "";
	}
        
        $text =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]//g;

	my $textnode = $self->{doc}->createTextNode( $text );

	return $textnode;
}

######################################################################
=pod

=item $DOM = $session->make_javascript( $code, %attribs )

Return a new DOM "script" element containing $code in javascript. %attribs will
be added to the script element, similar to make_element().

E.g.

	<script type="text/javascript">
	// <![CDATA[
	alert("Hello, World!");
	// ]]>
	</script>

=cut
######################################################################

sub make_javascript
{
	my( $self, $text, %attr ) = @_;

	if( !defined( $text ) )
	{
		$text = "";
	}
	chomp($text);

	my $script = $self->make_element( "script", type => "text/javascript", %attr );

	$script->appendChild( $self->make_text( "\n// " ) );
	$script->appendChild( $self->{doc}->createCDATASection( "\n$text\n// " ) );

	return $script;
}

######################################################################
=pod

=item $fragment = $session->make_doc_fragment

Return a new XML document fragment. This is an item which can have
XML elements added to it, but does not actually get rendered itself.

If appended to an element then it disappears and its children join
the element at that point.

=cut
######################################################################

sub make_doc_fragment
{
	my( $self ) = @_;

	return EPrints::XML::make_document_fragment( $self );
}






#############################################################
#############################################################
=pod

=back

=head2 XHTML Related Methods

These methods help build XHTML.

=over 4

=cut
#############################################################
#############################################################




######################################################################
=pod

=item $ruler = $session->render_ruler

Return an HR.
in ruler.xml

=cut
######################################################################

sub render_ruler
{
	my( $self ) = @_;

	return $self->html_phrase( "ruler" );
}

######################################################################
=pod

=item $nbsp = $session->render_nbsp

Return an XHTML &nbsp; character.

=cut
######################################################################

sub render_nbsp
{
	my( $self ) = @_;

	my $string = latin1(chr(160));

	return $self->make_text( $string );
}

######################################################################
=pod

=item $xhtml = $session->render_data_element( $indent, $elementname, $value, [%opts] )

This is used to help render neat XML data. It returns a fragment 
containing an element of name $elementname containing the value
$value, the element is indented by $indent spaces.

The %opts describe any extra attributes for the element

eg.
$session->render_data_element( 4, "foo", "bar", class=>"fred" )

would return a XML DOM object describing:
    <foo class="fred">bar</foo>

=cut
######################################################################

sub render_data_element
{
	my( $self, $indent, $elementname, $value, %opts ) = @_;

	my $f = $self->make_doc_fragment();
	my $el = $self->make_element( $elementname, %opts );
	$el->appendChild( $self->make_text( $value ) );
	$f->appendChild( $self->make_indent( $indent ) );
	$f->appendChild( $el );

	return $f;
}


######################################################################
=pod

=item $xhtml = $session->render_link( $uri, [$target] )

Returns an HTML link to the given uri, with the optional $target if
it needs to point to a different frame or window.

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

=item $table_row = $session->render_row( $key, @values );

Return the key and values in a DOM encoded HTML table row. eg.

 <tr><th>$key:</th><td>$value[0]</td><td>...</td></tr>

=cut
######################################################################

sub render_row
{
	my( $session, $key, @values ) = @_;

	my( $tr, $th, $td );

	$tr = $session->make_element( "tr" );

	$th = $session->make_element( "th", valign=>"top", class=>"ep_row" ); 
	if( !defined $key )
	{
		$th->appendChild( $session->render_nbsp );
	}
	else
	{
		$th->appendChild( $key );
		$th->appendChild( $session->make_text( ":" ) );
	}
	$tr->appendChild( $th );

	foreach my $value ( @values )
	{
		$td = $session->make_element( "td", valign=>"top", class=>"ep_row" ); 
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

sub render_row_with_help
{
	my( $self, %parts ) = @_;

	if( EPrints::XML::is_empty( $parts{help} ) )
	{
		delete $parts{help};
	}


	my $tr = $self->make_element( "tr", class=>$parts{class} );
	
	my $th = $self->make_element( "th", class=>"ep_multi_heading" );
	$th->appendChild( $parts{label} );
	$th->appendChild( $self->make_text( ":" ) );
	$tr->appendChild( $th );

	if( !defined $parts{help} )
	{
		my $td = $self->make_element( "td", class=>"ep_multi_input", colspan=>"2" );
		$tr->appendChild( $td );
		$td->appendChild( $parts{field} );
		return $tr;
	}

	my $td = $self->make_element( "td", class=>"ep_multi_input" );
	$tr->appendChild( $td );

	my $inline_help = $self->make_element( "div", id=>$parts{help_prefix}, class=>"ep_no_js ep_multi_inline_help" );
	my $inline_help_inner = $self->make_element( "div", id=>$parts{help_prefix}."_inner" );
	$inline_help->appendChild( $inline_help_inner );
	$inline_help_inner->appendChild( $parts{help} );
	$td->appendChild( $inline_help );

	$td->appendChild( $parts{field} );
	
	# help toggle

	my $td2 = $self->make_element( "td", class=>"ep_multi_help ep_only_js ep_toggle" );
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

sub render_toolbar
{
	my( $self ) = @_;

	my $screen_processor = bless {
		session => $self,
		screenid => "FirstTool",
	}, "EPrints::ScreenProcessor";

	my $screen = $screen_processor->screen;
	$screen->properties_from; 

	my $toolbar = $self->make_element( "span", class=>"ep_toolbar" );
	my $core = $self->make_element( "span", id=>"ep_user_menu_core" );
	$toolbar->appendChild( $core );

	my @core = $screen->list_items( "key_tools" );
	my @other = $screen->list_items( "other_tools" );
	my $url = $self->get_repository->get_conf( "http_cgiurl" )."/users/home";

	my $first = 1;
	foreach my $tool ( @core )
	{
		if( $first )
		{
			$first = 0;
		}
		else
		{
			$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );
		}
		my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$core->appendChild( $a );
	}

	if( scalar @other == 1 )
	{
		$core->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );	
		my $tool = $other[0];
		my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
		$a->appendChild( $tool->{screen}->render_title );
		$core->appendChild( $a );
	}
	elsif( scalar @other > 1 )
	{
		my $span = $self->make_element( "span", id=>"ep_user_menu_extra", class=>"ep_no_js_inline" );
		$toolbar->appendChild( $span );

		my $nojs_divide = $self->make_element( "span", class=>"ep_no_js_inline" );
		$nojs_divide->appendChild( 
			$self->html_phrase( "Plugin/Screen:tool_divide" ) );
		$span->appendChild( $nojs_divide );
		
		my $more_bit = $self->make_element( "span", class=>"ep_only_js" );
		my $more = $self->make_element( "a", id=>"ep_user_menu_more", href=>"#", onclick => "EPJS_blur(event); EPJS_toggle_type('ep_user_menu_core',true,'inline');EPJS_toggle_type('ep_user_menu_extra',false,'inline');return false", );
		$more->appendChild( $self->html_phrase( "Plugin/Screen:more" ) );
		$more_bit->appendChild( $self->html_phrase( "Plugin/Screen:tool_divide" ) );	
		$more_bit->appendChild( $more );
		$toolbar->appendChild( $more_bit );

		$first = 1;
		foreach my $tool ( @other )
		{
			if( $first )
			{
				$first = 0;
			}
			else
			{
				$span->appendChild( 
					$self->html_phrase( "Plugin/Screen:tool_divide" ) );
			}
			my $a = $self->render_link( $url."?screen=".substr($tool->{screen_id},8) );
			$a->appendChild( $tool->{screen}->render_title );
			$span->appendChild( $a );
		}
	
	}
		
	return $toolbar;
}


######################################################################
=pod

=item $xhtml = $session->render_language_name( $langid ) 
Return a DOM object containing the description of the specified language
in the current default language, or failing that from languages.xml

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

=item $xhtml = $session->render_type_name( $type_set, $type ) 

Return a DOM object containing the description of the specified type
in the type set. eg. "eprint", "article"

=cut
######################################################################

sub render_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->html_phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=item $string = $session->get_type_name( $type_set, $type ) 

As above, but return a utf-8 string. Used in <option> elements, for
example.

=cut
######################################################################

sub get_type_name
{
	my( $self, $type_set, $type ) = @_;

        return $self->phrase( $type_set."_typename_".$type );
}

######################################################################
=pod

=item $xhtml_name = $session->render_name( $name, [$familylast] )

$name is a ref. to a hash containing family, given etc.

Returns an XML DOM fragment with the name rendered in the manner
of the repository. Usually "John Smith".

If $familylast is set then the family and given parts are reversed, eg.
"Smith, John"

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

=item $xhtml_select = $session->render_option_list( %params )

This method renders an XHTML <select>. The options are complicated
and may change, so it's better not to use it.

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
	else
	{
		$defaults{$params{default}} = 1;
	}


	my $dtop = defined $params{defaults_at_top} && $params{defaults_at_top};


	my @alist = ();
	my @list = ();
	my $pairs = $params{pairs};
	if( !defined $pairs )
	{
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
		my $f = $self->make_doc_fragment;
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
			$f->appendChild( $div );
		}
		return $f;
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

=item $option = $session->render_single_option( $key, $desc, $selected )

Used by render_option_list.

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

=item $xhtml_hidden = $session->render_hidden_field( $name, $value )

Return the XHTML DOM describing an <input> element of type "hidden"
and name and value as specified. eg.

<input type="hidden" name="foo" value="bar" />

=cut
######################################################################

sub render_hidden_field
{
	my( $self , $name , $value ) = @_;

	if( !defined $value ) 
	{
		$value = $self->param( $name );
	}

	return $self->render_input_field( 
		name => $name,
		id => $name,
		value => $value,
		type => "hidden" );
}

sub render_input_field
{
	my( $self, @opts ) = @_;

	return $self->make_element( "input", @opts );
}

sub render_noenter_input_field
{
	my( $self, @opts ) = @_;

	return $self->make_element( "input",
		onKeyPress => "return EPJS_block_enter( event )",
		@opts,
	);
}


######################################################################
=pod

=item $xhtml_uploda = $session->render_upload_field( $name )

Render into XHTML DOM a file upload form button with the given name. 

eg.
<input type="file" name="foo" />

=cut
######################################################################

sub render_upload_field
{
	my( $self, $name ) = @_;

#	my $div = $self->make_element( "div" ); #no class cjg	
#	$div->appendChild( $self->make_element(
#		"input", 
#		name => $name,
#		type => "file" ) );
#	return $div;

	return $self->render_noenter_input_field(
		name => $name,
		type => "file" );

}


######################################################################
=pod

=item $dom = $session->render_action_buttons( %buttons )

Returns a DOM object describing the set of buttons.

The keys of %buttons are the ids of the action that button will cause,
the values are UTF-8 text that should appear on the button.

Two optional additional keys may be used:

_order => [ "action1", "action2" ]

will force the buttons to appear in a set order.

_class => "my_css_class" 

will add a class attribute to the <div> containing the buttons to 
allow additional styling.

=cut
######################################################################

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "action" , %buttons );
}


######################################################################
=pod

=item $dom = $session->render_internal_buttons( %buttons )

As for render_action_buttons, but creates buttons for actions which
will modify the state of the current form, not continue with whatever
process the form is part of.

eg. the "More Spaces" button and the up and down arrows on multiple
type fields.

=cut
######################################################################

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	return $self->_render_buttons_aux( "internal" , %buttons );
}


######################################################################
# 
# $dom = $session->_render_buttons_aux( $btype, %buttons )
#
######################################################################

sub _render_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	#my $frag = $self->make_doc_fragment();
	my $class = "";
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

	if( !defined $opts{onclick} )
	{
		$opts{onclick} = "return EPJS_button_pushed( '$opts{name}' )";	
	}
	
	if( !defined $opts{class} )
	{
		$opts{class} = "ep_form_action_button";
	}
	$opts{type} = "submit";

	return $self->make_element( "input", %opts );
}

######################################################################
=pod

=item $dom = $session->render_form( $method, $dest )

Return a DOM object describing an HTML form element. 

$method should be "get" or "post"

$dest is the target of the form. By default the current page.

eg.

$session->render_form( "GET", "http://example.com/cgi/foo" );

returns a DOM object representing:

<form method="get" action="http://example.com/cgi/foo" accept-charset="utf-8" />

If $method is "post" then an addition attribute is set:
enctype="multipart/form-data" 

This just controls how the data is passed from the browser to the
CGI library. You don't need to worry about it.

=cut
######################################################################

sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{doc}->createElement( "form" );
	$form->setAttribute( "method", "\L$method" );
	$form->setAttribute( "accept-charset", "utf-8" );
	if( !defined $dest )
	{
		$dest = $self->get_uri;
	}
	$form->setAttribute( "action", $dest );
	if( "\L$method" eq "post" )
	{
		$form->setAttribute( "enctype", "multipart/form-data" );
	}
	return $form;
}


######################################################################
=pod

=item $ul = $session->render_subjects( $subject_list, [$baseid], [$currentid], [$linkmode], [$sizes] )

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

$sizes may be a ref. to hash mapping the subjectid's to the number
of items in that subject which will be rendered in brackets next to
each subject.

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
# $ul = $session->_render_subjects_aux( $subjects, $id, $currentid, $linkmode, $sizes )
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

=item $session->render_error( $error_text, $back_to, $back_to_text )

Renders an error page with the given error text. A link, with the
text $back_to_text, is offered, the destination of this is $back_to,
which should take the user somewhere sensible.

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

=item $dom = $session->render_input_form( %params )

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
	if( defined $p{default_action} && $self->client() ne "LYNX" )
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

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	$form->appendChild( $self->render_hidden_field( "_seen", "true" ) );

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
# $xhtml_field = $session->_render_input_form_field( $field, $value, $show_names, $show_help, $comment, $dataset, $type, $staff, $hiddenfields, $object )
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
# $xhtml = $session->render_toolbox( $title, $content )
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
	my( $self, $type, $content ) = @_;

	my $id = "m".$self->get_next_id;
	my $div = $self->make_element( "div", class=>"ep_msg_".$type, id=>$id );
	my $content_div = $self->make_element( "div", class=>"ep_msg_".$type."_content" );
	my $table = $self->make_element( "table" );
	my $tr = $self->make_element( "tr" );
	$table->appendChild( $tr );
	my $td1 = $self->make_element( "td" );
	my $imagesurl = $self->get_repository->get_conf( "rel_path" );
	$td1->appendChild( $self->make_element( "img", class=>"ep_msg_".$type."_icon", src=>"$imagesurl/style/images/".$type.".png", alt=>$self->phrase( "Plugin/Screen:message_".$type ) ) );
	$tr->appendChild( $td1 );
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
# $xhtml = $session->render_tabs( %params )
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

	my $id_prefix = $params{id_prefix};
	my $current = $params{current};
	my $tabs = $params{tabs};
	my $labels = $params{labels};
	my $links = $params{links};
	
	my $f = $self->make_doc_fragment;
	my $st = {};
	if( defined $params{slow_tabs} )
	{
		foreach( @{$params{slow_tabs}} ) { $st->{$_} = 1; }
	}

	my $table = $self->make_element( "table", class=>"ep_tab_bar", cellspacing=>0, cellpadding=>0 );
	#my $script = $self->make_element( "script", type=>"text/javascript" );
	my $tr = $self->make_element( "tr", id=>"${id_prefix}_tabs" );
	$table->appendChild( $tr );

	my $spacer = $self->make_element( "td", class=>"ep_tab_spacer" );
	$spacer->appendChild( $self->render_nbsp );
	$tr->appendChild( $spacer );
	foreach my $tab ( @{$tabs} )
	{	
		my %a_opts = ( 
			href    => $links->{$tab},
		);
		my %td_opts = ( 
			class=>"ep_tab",
			id => "${id_prefix}_tab_$tab", 
		);
		# if the current tab is slow, or the tab we're rendering is slow then
		# don't make a javascript toggle for it.

		if( !$st->{$current} && !$st->{$tab} )
		{
			# stop the actual link from causing a reload.
			$a_opts{onclick} = "return ep_showTab('${id_prefix}','$tab' );",
		}
		elsif( $st->{$tab} )
		{
			$a_opts{onclick} = "ep_showTab('${id_prefix}','$tab' ); return true;",
		}
		if( $current eq $tab ) { $td_opts{class} = "ep_tab_selected"; }

		my $a = $self->make_element( "a", %a_opts );
		my $td = $self->make_element( "td", %td_opts );

		my $table2 = $self->make_element( "table", width=>"100%", cellpadding=>0, cellspacing=>0, border=>0 );
		my $tr2 = $self->make_element( "tr" );
		my $td2 = $self->make_element( "td", width=>"100%", style=>"text-align: center;" );
		$table2->appendChild( $tr2 );
		$tr2->appendChild( $td2 );
		$a->appendChild( $labels->{$tab} );
		$td2->appendChild( $a );
		if( defined $params{icons} )
		{
			if( defined $params{icons}->{$tab} )
			{
				my $td3 = $self->make_element( "td", style=>"text-align: right; padding-right: 4px" );
				$tr2->appendChild( $td3 );
				$td3->appendChild( $params{icons}->{$tab} );
			}
		}

		$td->appendChild( $table2 );

		$tr->appendChild( $td );

		my $spacer = $self->make_element( "td", class=>"ep_tab_spacer" );
		$spacer->appendChild( $self->render_nbsp );
		$tr->appendChild( $spacer );
	}
	$f->appendChild( $table );
	#$f->appendChild( $script );

	return $f;
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












#############################################################
#############################################################
=pod

=back

=head2 Methods relating to the current XHTML page

=over 4

=cut
#############################################################
#############################################################

######################################################################
=pod

=item $session->write_static_page( $filebase, $parts, [$page_id], [$wrote_files] )

Write an .html file plus a set of files describing the parts of the
page for use with the dynamic template option.

File base is the name of the page without the .html suffix.

parts is a reference to a hash containing DOM trees.

If $wrote_files is defined then any filenames written are logged in it as keys.

=cut
######################################################################

sub write_static_page
{
	my( $self, $filebase, $parts, $page_id, $wrote_files ) = @_;

	print "Writing: $filebase\n" if( $self->{noise} > 1 );
	
	my $dir = $filebase;
	$dir =~ s/\/[^\/]*$//;

	if( !-d $dir ) { EPrints::Platform::mkdir( $dir ); }

	foreach my $part_id ( keys %{$parts} )
	{
		my $file = $filebase.".".$part_id;
		if( open( CACHE, ">$file" ) )
		{
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

=item $session->prepare_page( $parts, %options )

Create an XHTML page for this session. 

$parts is a hash of XHTML elements to insert into the pins in the
template. Usually: title, page. Maybe pagetop and head.

If template is set then an alternate template file is used.

This function only builds the page it does not output it any way, see
the methods below for that.

Options include:

page_id=>"id to put in body tag"
template=>"The template to use instead of default."

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

	unless( $self->{offline} || !defined $self->{query} )
	{
		my $mo = $self->param( "mainonly" );
		if( defined $mo && $mo eq "yes" )
		{
			$self->{page} = $map->{page};
			return;
		}

		my $dp = $self->param( "debug_phrases" );
		# phrase debugging code.
		# disabled until we have a permission system planned.
		if( 0 && defined $dp && $dp eq "yes" )
		{
			my $table = $self->make_element( "table" );
			my $arc_langs = $self->{repository}->get_conf( "languages" );	
			foreach my $phraseid ( sort keys %{$self->{used_phrases}} )
			{
				my $tr = $self->make_element( "tr" );
				$table->appendChild( $tr );
				my $th = $self->make_element( "th" );
				my $td = $self->make_element( "td" );
				$tr->appendChild( $th );
				$th->appendChild( $self->make_text( $phraseid ) );
				$tr->appendChild( $td );

				my $t2 = $self->make_element( "table", border=>1, cellpadding=>4 );
				foreach my $langid ( @{$arc_langs} )
				{
					my $lang = $self->{repository}->get_language( $langid );
        				my( $phrase , $fb ) = $lang->_get_phrase( $phraseid, $self );
					my $tr2 = $self->make_element( "tr" );
					my $th2 = $self->make_element( "th" );
					my $td2 = $self->make_element( "td" );
					$t2->appendChild( $tr2 );
					$tr2->appendChild( $th2 );
					$tr2->appendChild( $td2 );
					$th2->appendChild( $self->make_text( "$langid" ) );
					if( defined $phrase )
					{
						$td2->appendChild( $self->make_text( EPrints::XML::contents_of( $phrase )->toString ) );
					}
				}
				$td->appendChild( $t2 );

			}
			$self->{page} = $table;
			return;
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
			$options{template_id} = "secure";
		}
		else
		{
			$options{template_id} = "default";
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
			my $result = EPrints::XML::to_string( EPrints::Script::print( $expr, { session=>$self } ), undef, 1 );
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
				if( defined $map->{"utf-8.".$pinid.".textonly"} )
				{
					push @output, $map->{"utf-8.".$pinid.".textonly"};
				}
				elsif( defined $map->{$pinid} )
				{
					# don't convert href's to <http://...>'s
					push @output, EPrints::Utils::tree_to_utf8( $map->{$pinid}, undef, undef, undef, 1 ); 
				}
				# else no title
		
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

=item $session->send_page( %httpopts )

Send a web page out by HTTP. Only relevant if this is a CGI script.
build_page must have been called first.

See send_http_header for an explanation of %httpopts

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
		print $self->{text_page};
	}
	else
	{
		print EPrints::XML::to_string( $self->{page}, undef, 1 );
		EPrints::XML::dispose( $self->{page} );
		delete $self->{page};
	}
	delete $self->{text_page};
}


######################################################################
=pod

=item $session->page_to_file( $filename, [$wrote_files] )

Write out the current webpage to the given filename.

build_page must have been called first.

Dispose of the XML once it's sent out.

If $wrote_files is set then keys are created in it for each file
created.

=cut
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
=pod

=item $session->set_page( $newhtml )

Erase the current page for this session, if any, and replace it with
the XML DOM structure described by $newhtml.

This page is what is output by page_to_file or send_page.

$newhtml is a normal DOM Element, not a document object.

=cut
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


######################################################################
=pod

=item $copy_of_node = $session->clone_for_me( $node, [$deep] )

XML DOM items can only be added to the document which they belong to.

A EPrints::Session has it's own XML DOM DOcument. 

This method copies an XML node from _any_ document. The copy belongs
to this sessions document.

If $deep is set then the children, (and their children etc.), are 
copied too.

=cut
######################################################################

sub clone_for_me
{
	my( $self, $node, $deep ) = @_;

	return EPrints::XML::clone_and_own( $node, $self->{doc}, $deep );
}


######################################################################
=pod

=item $session->redirect( $url, [%opts] )

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

######################################################################
=pod

=item $session->not_found( [ $message ] )

Send a 404 Not Found header. If $message is undef sets message to
'Not Found' but does B<NOT> print an error message, otherwise
defaults to the normal 404 Not Found type response.

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
}

######################################################################
=pod

=item $session->send_http_header( %opts )

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


#############################################################
#############################################################
=pod

=back

=head2 Input Methods

These handle input from the user, browser and apache.

=over 4

=cut
#############################################################
#############################################################




######################################################################
=pod

=item $value or @values = $session->param( $name )

Passes through to CGI.pm param method.

$value = $session->param( $name ): returns the value of CGI parameter
$name.

$value = $session->param( $name ): returns the value of CGI parameter
$name.

@values = $session->param: returns an array of the names of all the
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

	return( @result );

}

# $session->read_params
# 
# If we're online but have not yet read the CGI parameters then this
# will cause sesssion to read (and consume) them.

# If we're coming from cookie login page then grab the CGI params
# from an apache note set in Login.pm

sub read_params
{
	my( $self ) = @_;

	my $c = $self->{request}->connection;
	my $params = $c->notes->get( "loginparams" );
	if( defined $params && $params ne 'undef')
	{
 		$self->{query} = new CGI( $params ); 
	}
	else
	{
 		$self->{query} = new CGI;
	}

	$c->notes->set( loginparams=>'undef' );
}


######################################################################
=pod

=item $bool = $session->have_parameters

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

=item $user = $session->current_user

Return the current EPrints::DataObj::User for this session.

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
		if( $self->get_repository->can_call( 'get_current_user' ) )
		{
			$self->{current_user} = $self->get_repository->call( 'get_current_user', $self );
		}
		elsif( $self->get_archive->get_conf( "cookie_auth" ) ) 
		{
			$self->{current_user} = $self->_current_user_auth_cookie;
		}
		else
		{
			$self->{current_user} = $self->_current_user_auth_basic;
		}
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

	my $user = EPrints::DataObj::User::user_with_username( $self, $username );
	return $user;
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
	
	my $cookie = EPrints::Apache::AnApache::cookie( $self->get_request, "eprints_session" );

	return undef if( !defined $cookie );
	return undef if( $cookie eq "" );

	my $remote_addr = $c->get_remote_host;
	
	$userid = $self->{database}->get_ticket_userid( $cookie, $remote_addr );
	
	return undef if( !EPrints::Utils::is_set( $userid ) );

	my $user = EPrints::DataObj::User->new( $self, $userid );
	return $user;
}



######################################################################
=pod

=item $boolean = $session->seen_form

Return true if the current request contains the values from a
form generated by EPrints.

This is identified by a hidden field placed into forms named
_seen with value "true".

=cut
######################################################################

sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->param( "_seen" ) &&
	                $self->param( "_seen" ) eq "true" );

	return( $result );
}


######################################################################
=pod

=item $boolean = $session->internal_button_pressed( $buttonid )

Return true if a button has been pressed in a form which is intended
to reload the current page with some change.

Examples include the "more spaces" button on multiple fields, the 
"lookup" button on succeeds, etc.

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

=item $action_id = $session->get_action_button

Return the ID of the eprint action button which has been pressed in
a form, if there was one. The name of the button is "_action_" 
followed by the id. 

This also handles the .x and .y inserted in image submit.

This is designed to get back the name of an action button created
by render_action_buttons.

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
	return $self->param("_default_action");
}



######################################################################
=pod

=item $button_id = $session->get_internal_button

Return the id of the internal button which has been pushed, or 
undef if one wasn't.

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

=item $client = $session->client

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

# return the HTTP status.

######################################################################
=pod

=item $status = $session->get_http_status

Return the status of the current HTTP request.

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

=back

=head2 Methods related to Plugins

=over 4

=cut
#############################################################
#############################################################


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

	my $class = $EPrints::Plugin::REGISTRY->{$pluginid};

	if( !defined $class )
	{
		$self->{repository}->log( "Plugin '$pluginid' not found." );
		return undef;
	}

	my $plugin = $class->new( session=>$self, %params );	

	if( $plugin->param( "disable" ) )
	{
		return undef;
	}

	return $plugin;
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

	my %pids = ();
	foreach( EPrints::Plugin::plugin_list() ) { $pids{$_}=1; }

	return sort keys %pids if( !scalar %restrictions );
	my @out = ();
	foreach my $plugin_id ( sort keys %pids ) 
	{
		my $plugin = $self->plugin( $plugin_id );

		next if( !defined $plugin );

		# should we add this one to the list?
		my $add = 1;	
		foreach my $k ( keys %restrictions )
		{
			my $v = $restrictions{$k};
			next if( $plugin->matches( $k, $v ) );
			$add = 0;
		}
		
		next unless $add;	

		push @out, $plugin_id;
	}

	return @out;
}




#############################################################
#############################################################
=pod

=back

=head2 Other Methods

=over 4

=cut
#############################################################
#############################################################


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


sub valid_login
{
	my( $self, $username, $password ) = @_;

	my $valid_login_handler = sub { 
		my( $session,$username,$password ) = @_;
		return $session->get_database->valid_login( $username, $password );
	};
	if( $self->get_repository->can_call( "check_user_password" ) )
	{
		$valid_login_handler = $self->get_repository->get_conf( "check_user_password" );
	}

	return &{$valid_login_handler}( $self, $username, $password );
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


