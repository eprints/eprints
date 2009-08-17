######################################################################
#
# EPrints::Handle::CGI
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::Handle:::CGI> - :CGI methods for EPrins::Handle

=head1 DESCRIPTION

This module provides additional methods to EPrints::Handle and is not
an object in it's own right.

=over 4

=cut

use strict;

package EPrints::Handle;

######################################################################
=pod

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

######################################################################
=pod

=item $handle->not_found( [ $message ] )

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
# will cause sesssion to read (and consume) them.

# If we're coming from cookie login page then grab the CGI params
# from an apache note set in Login.pm

sub read_params
{
	my( $self ) = @_;

	my $r = $self->{request};
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

=item $boolean = $handle->seen_form

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

=item $boolean = $handle->internal_button_pressed( $buttonid )

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

=item $action_id = $handle->get_action_button

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
	$p = $self->param("_default_action");
	return $p if defined $p;

	return "";
}



######################################################################
=pod

=item $button_id = $handle->get_internal_button

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

# return the HTTP status.

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

	my $lang = EPrints::Handle::get_language( $repository, $r );
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
		my( $handle,$username,$password ) = @_;
		return $handle->get_database->valid_login( $username, $password );
	};
	if( $self->get_repository->can_call( "check_user_password" ) )
	{
		$valid_login_handler = $self->get_repository->get_conf( "check_user_password" );
	}

	return &{$valid_login_handler}( $self, $username, $password );
}





1;
