######################################################################
#
# EPrint Session
#
#  Holds information about a particular EPrint session.
#
#
#  Fields are:
#    database        - EPrints::Database object
#    renderer        - EPrints::HTMLRender object
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

package EPrints::Session;

use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Language;
use EPrints::Site;

use XML::DOM;

use strict;

######################################################################
#
# new( $offline )
#
#  Start a new EPrints session, opening a database connection,
#  creating a CGI query object and any other necessary session state
#  things.
#
#  Command line scripts should pass in true for $offline.
#  Apache-invoked scripts can omit it or pass in 0.
#
######################################################################

sub new
{
	my( $class, $mode, $param) = @_;
	# mode = 0    - We are online (CGI script)
	# mode = 1    - We are offline (bin script) param is siteid
	# mode = 2    - We are offline (auth) param is host and path.	
	my $self = {};
	bless $self, $class;

	$self->{query} = ( $mode==0 ? new CGI() : new CGI( {} ) );

	# Errors in english - no configuration yet.
	# These are pretty fatal - nothing will work if
	# this bit dosn't.

	my $offline;

	if( $mode == 0 || !defined $mode )
	{
		$offline = 0;
		$self->{site} = EPrints::Site->new_site_by_url( $self->{query}->url() );
		if( !defined $self->{site} )
		{
			die "Can't load site module for URL: ".$self->{query}->url();
		}
		$self->{page} = new XML::DOM::Document;
	}
	elsif( $mode == 1 )
	{
		if( !defined $param || $param eq "" )
		{
			die "No site id specified.";
		}
		$offline = 1;
		$self->{site} = EPrints::Site->new_site_by_id( $param );
		if( !defined $self->{site} )
		{
			die "Can't load site module for: $param";
		}
	}
	elsif( $mode == 2 )
	{
		$offline = 1;
		$self->{site} = EPrints::Site->new_site_by_host_and_path( $param );
		if( !defined $self->{site} )
		{
			die "Can't load site module for URL: $param";
		}
	}
	else
	{
		die "Unknown session mode: $mode";
	}

	#### Got Site Config Module ###

	#print $self->{site}->getConf( "htmlpage" );
	#my $parser = XML::DOM::Parser->new();
	#$self->{domtree} = $parser->parse( $self->{site}->getConf( "htmlpage" ) );
	#my @foo = $self->{domtree}->getElementsByTagName( "TITLEHERE" , 1 );
	#print join(",",@foo)."\n";
#
	#foreach(@foo) 
	#{
		#my $element = $self->{domtree}->createTextNode( "Hi Tim!" );
		#$_->getParentNode()->replaceChild( $element, $_ );
	#}
	#print $self->{domtree}->toString();
#
#die "OK!";

	my $langcookie = $self->{query}->cookie( $self->{site}->getConf( "lang_cookie_name") );
	if( defined $langcookie && !defined $EPrints::Site::General::languages{ $langcookie } )
	{
		$langcookie = undef;
	}
	$self->{lang} = EPrints::Language::fetch( $self->{site} , $langcookie );

	# Create a database connection
	$self->{database} = EPrints::Database->new( $self );
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->failure( $self->{lang}->phrase( "H:fail_db_connect" ) );
	}

#$self->{starttime} = gmtime( time );

#EPrints::Log::debug( "Session", "Started session at $self->{starttime}" );
	
	$self->{site}->call( "session_init", $self, $offline );

#
#	my @params = $self->{render}->{query}->param();
#	
#	foreach (@params)
#	{
#		my @vals = $self->{render}->{query}->param($_);
#		EPrints::Log::debug( "Session", "Param <$_> Values:<".@vals.">" );
#	}
	

	return( $self );
}

sub change_lang
{
	my( $self, $newlangid ) = @_;

	$self->{lang} = EPrints::Language::fetch( $self->{site} , $newlangid );
}


######################################################################
#
# failure()
#
#  Print an error messages describing why an operation has failed.
#
######################################################################

sub failure
{
	my( $self, $problem ) = @_;
	
	$self->{render}->render_error( $problem,
	                               $self->{site}->getConf( "frontpage" ),
	                               $self->{site}->getConf( "sitename" ) );
}


######################################################################
#
# terminate()
#
#  Perform any cleaning up necessary
#
######################################################################

sub terminate
{
	my( $self ) = @_;
	
#EPrints::Log::debug( "Session", "Closing session started at $self->{starttime}" );
	$self->{site}->call( "session_close", $self );

	$self->{database}->disconnect();

}


######################################################################
#
# mail_administrator( $subject, $message )
#
#  Sends a mail to the site administrator with the given subject and
#  message body.
#
######################################################################

sub mail_administrator
{
	my( $self, $subject, $message ) = @_;

	# cjg logphrase here will NOT do it no longer exists.
	
	my $message_body = EPrints::Language::logphrase( "msg_at" ,
	                                             { time=>gmtime( time ) } );
	$message_body .= "\n\n$message\n";

	EPrints::Mailer::send_mail(
		$self,
		EPrints::Language::logphrase( "site_admin" ),
		$self->{site}->{admin},
		$subject,
		$message_body );
}


sub phrase
{
	my( $self, $phraseid , $inserts ) = @_;

        my @callinfo = caller();
        $callinfo[1] =~ m#[^/]+$#;
        return $self->{lang}->file_phase( $& , $phraseid , $inserts );
}

sub getDB
{
	my( $self ) = @_;
	return $self->{database};
}

sub get_query
{
	my( $self ) = @_;
	return $self->{query};
}

sub getSite
{
	my( $self ) = @_;
	return $self->{site};
}

######################################################################
#
# $html = start_html( $title )
#
#  Return a standard HTML header, with any title or logo we might
#   want
#
######################################################################

sub start_html
{
	my( $self, $title, $langid ) = @_;

	my $html = "";
	
	# Write HTTP headers if appropriate
	unless( $self->{offline} )
	{
		my $r = Apache->request;
		$r->content_type( 'text/html' );
		if( defined $langid )
		{
			my $cookie = $self->{query}->cookie(
				-name    => $self->{site}->getConf("lang_cookie_name"),
				-path    => "/",
				-value   => $langid,
				-expires => "+10y", # really long time
				-domain  => $self->{site}->getConf("lang_cookie_domain") );
			$r->header_out( "Set-Cookie"=>$cookie ); 
print STDERR "COOK".$cookie."\n";
		}
		$r->send_http_header;
	}
	else
	{
		print STDERR "Header when offline\n";
	}

	my %opts = %{$self->{site}->getConf("start_html_params")};
	$opts{-title} = $self->{site}->getConf("sitename").": $title";


	$html .= $self->{query}->start_html( %opts );
	# Logo
	my $banner = $self->{site}->getConf("html_banner");
	$banner =~ s/TITLE_PLACEHOLDER/$title/g;

	$html .= "$banner\n";

	return( $html );
}


######################################################################
#
# end_html()
#
#  Write out stuff at the bottom of the page. Any standard navigational
#  stuff might go in here.
#
######################################################################

sub end_html
{
	my( $self ) = @_;
	
	# End of HTML gubbins
	my $html = $self->{site}->getConf("html_tail")."\n";
	$html .= $self->{query}->end_html;

	return( $html );
}


######################################################################
#
# $url = url()
#
#  Returns the URL of the current script
#
######################################################################

sub url
{
	my( $self ) = @_;
	
	return( $self->{query}->url() );
}

######################################################################
#
# $html = start_get_form( $dest )
#
#  Return form preamble, using GET method. 
#
######################################################################

sub start_get_form
{
	my( $self, $dest ) = @_;
	
	if( defined $dest )
	{
		return( $self->{query}->start_form( -method=>"GET",
		                                    -action=>$dest ) );
	}
	else
	{
		return( $self->{query}->start_form( -method=>"GET" ) );
	}
}


######################################################################
#
# $html = end_form()
#
#  Return end of form HTML stuff.
#
######################################################################

sub end_form
{
	my( $self ) = @_;
	return( $self->{query}->endform );
}

######################################################################
#
# $html = render_submit_buttons( $submit_buttons )
#                           array_ref
#
#  Returns HTML for buttons all with the name "submit" but with the
#  values given in the array. A single "Submit" button is printed
#  if the buttons aren't specified.
#
######################################################################

sub render_submit_buttons
{
	my( $self, $submit_buttons ) = @_;

	my $html = "";
	my $first = 1;

	if( defined $submit_buttons )
	{
		my $button;
		foreach $button (@$submit_buttons)
		{
			# Some space between them
			$html .= "&nbsp;&nbsp;" if( $first==0 );

			$html .=  $self->{query}->submit( -name=>"submit", -value=>$button );
			$first = 0 if( $first );
		}
	}
	else
	{
		$html = $self->{query}->submit( -name=>"submit", -value=>"Submit" );
	}

	return( $html );
}

sub get_order_names
{
	my( $self, $dataset ) = @_;
print STDERR "SELF:".join(",",keys %{$self} )."\n";
		
	my %names = ();
	foreach( keys %{$self->{site}->getConf(
			"order_methods",
			$dataset->toString() )} )
	{
		$names{$_}=$self->get_order_name( $dataset, $_ );
	}
	return( \%names );
}

sub get_order_name
{
	my( $self, $dataset, $orderid ) = @_;
	
        return $self->{lang}->phrase( 
		"ordername_".$dataset->toString()."_".$orderid );
}


######################################################################
#
# $param = param( $name )
#
#  Return a query parameter.
#
######################################################################

sub param
{
	my( $self, $name ) = @_;

	return( $self->{query}->param( $name ) ) unless wantarray;
	
	# Called in an array context
	my @result;

	if( defined $name )
	{
		@result = $self->{query}->param( $name );
	}
	else
	{
		@result = $self->{query}->param();
	}

	return( @result );

}

######################################################################
#
# $bool = have_parameters()
#
#  Return true if the current script had any parameters (POST or GET)
#
######################################################################

sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->{query}->param();

	return( scalar @names > 0 );
}


#############################################################


sub make_option_list
{
	my( $self , %params ) = @_;

	my %defaults = ();
	if( ref( $self->{default} ) eq "ARRAY" )
	{
		foreach( @{$self->{default}} )
		{
			$defaults{$_}++;
		}
	}
	else
	{
		$defaults{$self->{default}}++;
	}

	my $element = $self->make_element( "SELECT" , name => $params{name} );
	if( defined $params{size} )
	{
		$element->setAttribute( "size" , $params{size} );
	}
	if( defined $params{multiple} )
	{
		$element->setAttribute( "multiple" , $params{multiple} );
	}
	foreach( @{$params{values}} )
	{
		my $opt = $self->make_element( "OPTION", name => $_ );
		$opt->appendChild( 
			$self->{page}->createTextNode( 
				$params{labels}->{$_} ) );
		if( defined $defaults{$_} )
		{
			$opt->setAttribute( "SELECTED" , undef );
		}
		$element->appendChild( $opt );
	}
	return $element;
}

sub make_element
{
	my( $self , $ename , %params ) = @_;

	my $element = $self->{page}->createElement( $ename );
	foreach( keys %params )
	{
		$element->setAttribute( $_ , $params{$_} );
	}
	return $element;
}

1;
