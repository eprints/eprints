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
use Unicode::String qw(utf8 latin1);


use XML::DOM;
use XML::Parser;

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

## WP1: BAD
sub new
{
	my( $class, $mode, $param) = @_;
	# mode = 0    - We are online (CGI script)
	# mode = 1    - We are offline (bin script) param is siteid
	# mode = 2    - We are offline (auth) param is host and path.	
	my $self = {};
	bless $self, $class;

	$self->{query} = ( $mode==0 ? new CGI() : new CGI( {} ) );

	my $offline;

	if( $mode == 0 || !defined $mode )
	{
		$offline = 0;
		$self->{site} = EPrints::Site->new_site_by_url( $self->{query}->url() );
		if( !defined $self->{site} )
		{
			#cjg icky error handler...
			my $r = Apache->request;
			$r->content_type( 'text/html' );
			$r->send_http_header;
			print "<p>EPRINTS SERVER: Can't load site module for URL: ".$self->{query}->url()."</p>\n";
			
			print STDERR "xCan't load site module for URL: ".$self->{query}->url()."\n";

			return undef;
			
		}
	}
	elsif( $mode == 1 )
	{
		$offline = 1;
		if( !defined $param || $param eq "" )
		{
			print STDERR "No site id specified.\n";
			return undef;
		}
		$self->{site} = EPrints::Site->new_site_by_id( $param );
		if( !defined $self->{site} )
		{
			print STDERR "Can't load site module for: $param\n";
			return undef;
		}
	}
	elsif( $mode == 2 )
	{
		$offline = 1;
		$self->{site} = EPrints::Site->new_site_by_host_and_path( $param );
		if( !defined $self->{site} )
		{
			print STDERR "Can't load site module for URL: $param\n";			return undef;
			return undef;
		}
	}
	else
	{
		print STDERR "Unknown session mode: $mode\n";
		return undef;
	}

	#### Got Site Config Module ###

	# What language is this session in?

	my $langcookie = $self->{query}->cookie( $self->{site}->getConf( "lang_cookie_name") );
	if( defined $langcookie && !defined $EPrints::Site::General::languages{ $langcookie } )
	{
		$langcookie = undef;
	}
	$self->{lang} = EPrints::Language::fetch( $self->{site} , $langcookie );
	
	$self->newPage;

	# Create a database connection
	$self->{database} = EPrints::Database->new( $self );
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->phrase( "fail_db_connect" ) );
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

## WP1: BAD
sub newPage
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->{lang}->getID;
	}

	$self->{page} = new XML::DOM::Document;

	XML::DOM::setTagCompression( \&_tag_compression );

	my $doctype = XML::DOM::DocumentType->new(
			"foo", #cjg what's this bit?
			"html",
			"DTD/xhtml1-transitional.dtd",
			"-//W3C//DTD XHTML 1.0 Transitional//EN" );
	$self->takeOwnership( $doctype );
	$self->{page}->setDoctype( $doctype );

	my $xmldecl = $self->{page}->createXMLDecl( "1.0", "UTF-8", "yes" );
	$self->{page}->setXMLDecl( $xmldecl );

	my $newpage = $self->{site}->getConf( "htmlpage" , $langid )->cloneNode( 1 );
	$self->takeOwnership( $newpage );
	$self->{page}->appendChild( $newpage );
}

#WP1 GOOD
sub _tag_compression
{
	my ($tag, $elem) = @_;

	# Print empty br, hr and img tags like this: <br />
	return 2 if $tag =~ /^(br|hr|img)$/;
	
	# Print other empty tags like this: <empty></empty>
	return 1;
}


## WP1: BAD
sub change_lang
{
	my( $self, $newlangid ) = @_;

	$self->{lang} = EPrints::Language::fetch( $self->{site} , $newlangid );
}


######################################################################
#
# terminate()
#
#  Perform any cleaning up necessary
#
######################################################################

## WP1: BAD
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

## WP1: BAD
sub mail_administrator
{
	my( $self, $subject, $message ) = @_;

	# cjg logphrase here will NOT do it no longer exists.
	
	my $message_body = "msg_at".gmtime( time );
	$message_body .= "\n\n$message\n";

	EPrints::Mailer::send_mail(
		$self,
		 "site_admin" ,
		$self->{site}->{admin},
		$subject,
		$message_body );
}

## WP1: BAD
sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;

        my @callinfo = caller();
        $callinfo[1] =~ m#[^/]+$#;
        my $result = $self->{lang}->file_phrase( 
					$& , 
					$phraseid , 
					\%inserts , 
					$self );
	print STDERR ">>>".$result->toString."\n";
	return $self->treeToXHTML( $result );
}

## WP1: GOOD
sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	foreach( keys %inserts )
	{
		$inserts{$_} = $self->makeText( $inserts{$_} );
		
	}
        my @callinfo = caller();
        $callinfo[1] =~ m#[^/]+$#;

        my $r = $self->{lang}->file_phrase( $&, $phraseid, \%inserts , $self);

	return $self->treeToUTF8( $r );
}

## WP1: BAD
sub treeToUTF8
{
	my( $self, $node ) = @_;


	my $name = $node->getNodeName;
	if( $name eq "#text" || $name eq "#cdata-section")
	{
		return $node->getNodeValue;
	}

	my $string = "";
	foreach( $node->getChildNodes )
	{
		$string .= $self->treeToUTF8( $_ );
	}

	if( $name eq "fallback" )
	{
		$string = latin1("*").$string.latin1("*");
	}

	return $string;
	
}

## WP1: BAD
sub treeToXHTML
{
	my( $self, $node ) = @_;

	return $node;
}
	

	

## WP1: BAD
sub getDB
{
	my( $self ) = @_;
	return $self->{database};
}

## WP1: BAD
sub get_query
{
	my( $self ) = @_;
	return $self->{query};
}

## WP1: BAD
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

## WP1: BAD
sub sendHTTPHeader
{
	my( $self, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{offline} )
	{
		$self->{site}->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	my $r = Apache->request;
	$r->content_type( 'text/html; charset=UTF8' );

	if( defined $opts{lang} )
	{
		my $cookie = $self->{query}->cookie(
			-name    => $self->{site}->getConf("lang_cookie_name"),
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{site}->getConf("lang_cookie_domain") );
		$r->header_out( "Set-Cookie"=>$cookie ); 
	}
	$r->send_http_header;
}

## WP1: BAD
sub start_html
{
	my( $self, $title, $langid ) = @_;
die "NOPE";

	$self->sendHTTPHeader();

	my $html = "<BODY> begin here ";

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

## WP1: BAD
sub end_html
{
	my( $self ) = @_;
die "NOPE";
	
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

## WP1: BAD
sub getURL
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

## WP1: BAD
sub start_get_form
{
	my( $self, $dest ) = @_;
die "NOPE";

		
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

## WP1: BAD
sub end_form
{
die "NOPE";
	my( $self ) = @_;
	return( $self->{query}->endform );
}

######################################################################
#
# $html = render_submit_buttons( $submit_buttons )
#                                array_ref
#
#  Returns HTML for buttons all with the name "submit" but with the
#  values given in the array. A single "Submit" button is printed
#  if the buttons aren't specified.
#
######################################################################


## WP1: BAD
sub get_order_names
{
	my( $self, $dataset ) = @_;
print STDERR "SELF:".join(",",keys %{$self} )."\n";
		
	my %names = ();
	foreach( keys %{$self->{site}->getConf(
			"order_methods",
			$dataset->confid() )} )
	{
		$names{$_}=$self->get_order_name( $dataset, $_ );
	}
	return( \%names );
}

## WP1: BAD
sub get_order_name
{
	my( $self, $dataset, $orderid ) = @_;
	
        return $self->phrase( 
		"ordername_".$dataset->toString()."_".$orderid );
}


######################################################################
#
# $param = param( $name )
#
#  Return a query parameter.
#
######################################################################

## WP1: BAD
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
		@result = $self->{query}->param;
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

## WP1: BAD
sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->{query}->param();

	return( scalar @names > 0 );
}


#############################################################


## WP1: BAD
sub make_option_list
{
	my( $self , %params ) = @_;

	#cjg What IS this shit?
	my %defaults = ();
	if( ref( $params{default} ) eq "ARRAY" )
	{
		foreach( @{$params{default}} )
		{
			$defaults{$_}++;
		}
	}
	else
	{
		$defaults{$params{default}}++;
	}

	my $element = $self->make_element( "select" , name => $params{name} );
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
		my $opt = $self->make_element( "option", value => $_ );
		$opt->appendChild( 
			$self->{page}->createTextNode( 
				$params{labels}->{$_} ) );
		if( defined $defaults{$_} )
		{
			$opt->setAttribute( "selected" , "selected" );
		}
		$element->appendChild( $opt );
	}
	return $element;
}

## WP1: BAD
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

## WP1: BAD
sub make_hidden_field
{
	my( $self , $name , $value ) = @_;

	if( defined $self->param( $name ) )
	{
		$value = $self->param( $name );
	}

	return $self->make_element( "input",
		name => $name,
		value => $value,
		type => "hidden" );
}

## WP1: BAD
sub make_submit_buttons
{
	my( $self, @submit_buttons ) = @_;

	my $html = "";

	if( scalar @submit_buttons == 0 )
	{
# lang me cjg
		@submit_buttons = ( "Submit" );
	}

	my $frag = $self->makeDocFragment;

	foreach( @submit_buttons )
	{
		# Some space between them
		$frag->appendChild(
			$self->make_element( "input",
				class => "submitbutton",
				type => "submit",
				name => "_submit",
				value => $_ ) );
		$frag->appendChild( $self->makeText( latin1(" ") ) );
	}

	return( $frag );
}

# $text is a UTF8 String!
## WP1: BAD
sub makeText
{
	my( $self , $text ) = @_;

	return $self->{page}->createTextNode( $text );
}

## WP1: BAD
sub makeDocFragment
{
	my( $self ) = @_;

	return $self->{page}->createDocumentFragment;
}

## WP1: BAD (dest is optional)
#cjg "POST" forms must be utf8 and multipart
sub make_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{page}->createElement( "form" );
	$form->setAttribute( "method", $method );
	$dest = $ENV{SCRIPT_NAME} if( !defined $dest );
	$form->setAttribute( "action", $dest );
	return $form;
}

## WP1: BAD
sub bomb
{	
	my @info;
	print STDERR "=======================================\n";
	print STDERR "=      EPRINTS BOMB                   =\n";
	print STDERR "=======================================\n";
	my $i=1;
	while( @info = caller($i++) )
	{
		print STDERR $info[3]." ($info[2])\n";
	}
	print STDERR "=======================================\n";
	exit;
}

## WP1: BAD
sub takeOwnership
{
	my( $self , $domnode ) = @_;

	$domnode->setOwnerDocument( $self->{page} );
}

## WP1: BAD
sub buildPage
{
	my( $self, $title, $mainbit ) = @_;
	
	$self->takeOwnership( $mainbit );
	my $node;
	foreach $node ( $self->{page}->getElementsByTagName( "titlehere" , 1 ) )
	{
		my $element = $self->{page}->createTextNode( $title );
		$node->getParentNode()->replaceChild( $element, $node );
		$node->dispose();
	}
	foreach $node ( $self->{page}->getElementsByTagName( "pagehere" , 1 ) )
	{
		$node->getParentNode()->replaceChild( $mainbit, $node );
		$node->dispose();
	}
}

## WP1: BAD
sub sendPage
{
	my( $self, %httpopts ) = @_;
	$self->sendHTTPHeader( %httpopts );
	print $self->{page}->toString;
	$self->{page}->dispose();
}

## WP1: BAD
sub pageToFile
{
	my( $self , $filename ) = @_;

	$self->{page}->printToFile( $filename );

}

## WP1: BAD
sub setPage
{
	my( $self, $newhtml ) = @_;
	
	my $html = ($self->{page}->getElementsByTagName( "html" ))[0];
	$self->{page}->removeChild( $html );
	$self->{page}->appendChild( $newhtml );
	$html->dispose();
}

	
	
######################################################################
#
# $html = subject_tree( $subject )
#
#  Return HTML for a subject tree for the given subject. If $subject is
#  undef, the root subject is assumed.
#
#  The tree will feature the current tree, the parents up to the root,
#  and all children.
#
######################################################################

## WP1: BAD
sub subjectTree
{
	my( $self, $subject ) = @_;

	my $frag = $self->makeDocFragment;
	
	# Get the parents
	my $parent = $subject->parent;
	my @parents;
	
	while( defined $parent )
	{
		push @parents, $parent;
		$parent = $parent->parent;
	}
	
	# Render the parents
	my $ul = $self->make_element( "ul" );
	$frag->appendChild( $ul );
	while( $#parents >= 0 )
	{
		$parent = pop @parents;

		my $li = $self->make_element( "li" );
		$li->appendChild(
			$self->subject_desc( $parent, 1, 0, 1 ) );
		$ul->appendChild( $li );
		my $newul = $self->make_element( "ul" );
		$ul->appendChild( $newul );
		$ul = $newul;
	}
	
	# Render this subject
	if( defined $subject &&
		( $subject->{subjectid} ne $EPrints::Subject::root_subject ) )
	{
		my $li = $self->make_element( "li" );
		$li->appendChild(
			$self->subject_desc( $subject, 0, 0, 1 ) );
		$ul->appendChild( $li );
		my $newul = $self->make_element( "ul" );
		$ul->appendChild( $newul );
		$ul = $newul;
	}
	
	# Render children
	$ul->appendChild( $self->_render_children( $subject ) );

	return( $frag );
}

######################################################################
#
# $html = _render_children( $subject )
#
#  Recursively render the children of the given subject into HTML lists.
#
######################################################################

## WP1: BAD
sub _render_children
{
	my( $self, $subject ) = @_;

	my $frag = $self->makeDocFragment;
	my @children = $subject->children;

print "ooooooooooooooooooook: ".(scalar @children)."\n";
print "doin:\n";
print EPrints::Log::render_struct( $subject );
print "has ".(scalar @children)." kids\n";
	if( @children )
	{
print "ek:\n";
		my $ul = $self->make_element( "ul" );
		$frag->appendChild( $ul );
	
		foreach (@children)
		{
print "zoop\n";
			my $li = $self->make_element( "li" );
			
			$li->appendChild( $self->subject_desc( $_, 1, 0, 1 ) );
			$li->appendChild( $self->_render_children( $_ ) );
			$ul->appendChild( $li );
		}
		
	}
	
	return( $frag );
}


######################################################################
#
# $html = subject_desc( $subject, $link, $full, $count )
#
#  Return the HTML to render the title of $subject. If $link is non-zero,
#  the title is linked to the static subject view. If $full is non-zero,
#  the full name of the subject is given. If $count is non-zero, the
#  number of eprints in that subject is appended in brackets.
#
######################################################################

## WP1: BAD
sub subject_desc
{
	my( $self, $subject, $link, $full, $count ) = @_;
	
	my $frag;
	if( $link )
	{
		$frag = $self->make_element(
				"a",
				href=>
			$self->getSite->getConf( "server_static" ).
			"/view/".$subject->{subjectid}.".html" );
	}
	else
	{
		$frag = $self->makeDocFragment;
	}
	

	if( defined $full && $full )
	{
		$frag->appendChild( $self->makeText(
			EPrints::Subject::subject_label( 
						$self,
		                                $subject->{subjectid} ) ) );
	}
	else
	{
		$frag->appendChild( $self->makeText( $subject->{name} ) );
	}
		
	if( $count && $subject->{depositable} eq "TRUE" )
	{
		my $text = $self->makeText( 
			latin1(" (" .$subject->count_eprints( 
				$self->getSite->getDataSet( "archive" ) ).
				")" ) );
		$frag->appendChild( $text );
	}
	
	return( $frag );
}


######################################################################
#
# render_error( $error_text, $back_to, $back_to_text )
#
#  Renders an error page with the given error text. A link, with the
#  text $back_to_text, is offered, the destination of this is $back_to,
#  which should take the user somewhere sensible.
#
######################################################################

## WP1: GOOD
sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;
	
	if( !defined $back_to )
	{
		$back_to = $self->getSite->getConf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
		$back_to_text = "Continue"; #XXX INTL cjg
	}

	if ( $self->{offline} )
	{
		print $self->phrase( 
			"some_error",
			sitename=>$self->{session}->{site}->{sitename} );
		print "\n\n";
		print "$error_text\n\n";
	} 
	else
	{
		my( $p, $page, $a );
		$page = $self->makeDocFragment;

		$p = $self->make_element( "p" );
		$p->appendChild( $self->html_phrase( 
			"some_error",
			sitename => $self->makeText( 
				$self->getSite->getConf( "sitename" ) ) ) );
		$page->appendChild( $p );

		$p = $self->make_element( "p" );
		$p->appendChild( $self->makeText( $error_text ) );
		$page->appendChild( $p );

		$p = $self->make_element( "p" );
		$p->appendChild( $self->html_phrase( 
			"contact",
			adminemail => $self->make_element( 
				"a",
				href => "mailto:".
					$self->getSite->getConf( "admin" ) ),
			sitename => $self->makeText(
				$self->getSite->getConf( "sitename" ) ) ) );
		$page->appendChild( $p );
				
		$p = $self->make_element( "p" );
		$a = $self->make_element( 
				"a",
				href => $back_to );
		$a->appendChild( $self->makeText( $back_to_text ) );
		$p->appendChild( $a );
		$page->appendChild( $p );

		$self->buildPage(	
			$self->phrase( "error_title" ),
			$page );

		$self->sendPage;
	}
}

## WP1: GOOD
sub auth_check
{
	my( $self , $resource ) = @_;

	my $user = $self->current_user;

	if( !defined $user )
	{
		$self->render_error( $self->phrase( "no_login" ) );
		return 0;
	}

	# Don't need to do any more if we aren't checking for a specific
	# resource.
	if( !defined $resource )
	{
		return 1;
	}

	unless( $user->has_priv( $resource ) )
	{
		$self->render_error( $self->phrase( "no_priv" ) );
		return 0;
	}
	return 1;
}


## WP1: GOOD
sub current_user
{
	my( $self ) = @_;

	my $user = undef;

	# If we've already done this once, no point
	# in doing it again.
	unless( defined $self->{currentuser} )
	{	
		my $username = $ENV{'REMOTE_USER'};

		if( defined $username && $username ne "" )
		{
			$self->{currentuser} = 
					new EPrints::User( $self, $username );
		}
	}

	return $self->{currentuser};
}


## WP1: BAD
sub seen_form
{
	my( $self ) = @_;
	
	my $result = 0;

	$result = 1 if( defined $self->{query}->param( "_seen" ) &&
	                $self->{query}->param( "_seen" ) eq "true" );

	return( $result );
}

## WP1: BAD cjg BOY IS THIS SOOO NOT FINISHED.
sub internal_button_pressed
{
	my( $self ) = @_;
	
        return( defined $self->{query}->param( '_internal' ) );
}

######################################################################
#
# render_form( $fields,              #array_ref
#              $values,              #hash_ref
#              $show_names,
#              $show_help,
#              $submit_buttons,      #array_ref
#              $hidden_fields,       #hash_ref
#              $dest
#
#  Renders an HTML form. $fields is a reference to metadata fields
#  in the usual format. $values should map field names to existing values.
#  This function also puts in a hidden parameter "seen" and sets it to
#  true. That way, a calling script can check the value of the parameter
#  "seen" to see if the users seen and responded to the form.
#
#  Submit buttons are specified in a reference to an array of names.
#  If $submit_buttons isn't passed in (or is undefined), a simple
#  default "Submit" button is slapped on.
#
#  $dest should contain the URL of the destination
#
######################################################################

## WP1: BAD
sub render_form
{
	my( $self, $fields, $values, $show_names, $show_help, $submit_buttons,
	    $hidden_fields, $dest ) = @_;

print STDERR EPrints::Log::render_struct( $values );

	my $query = $self->{query};

	my( $form );

	$form =	$self->make_form( "post", $dest );

	my $field;	
	foreach $field (@$fields)
	{
print STDERR "==>".$field->getName()." = ".$values->{$field->getName()}."\n";
		$form->appendChild( $self->render_form_field( 
					     $field,
		                             $values->{$field->getName()},
		                             $show_names,
		                             $show_help ) );
	}

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	$form->appendChild( $self->make_hidden_field( "_seen", "true" ) );

	if( defined $hidden_fields )
	{
		foreach (keys %{$hidden_fields})
		{
			$form->appendChild( $self->make_hidden_field( 
						$_, 
						$hidden_fields->{$_} ) );
		}
	}

	$form->appendChild( $self->make_submit_buttons( @{$submit_buttons} ) );

	return $form;
}


######################################################################
#
# $html = input_field_tr( $field, $value, $show_names, $show_help )
#
#  Write a table row with the given field and value.
#
######################################################################

## WP1: BAD
sub render_form_field
{
	my( $self, $field, $value, $show_names, $show_help ) = @_;
	
	my( $div, $html, $span );

	$html = $self->makeDocFragment();

	if( $show_names )
	{
		$div = $self->make_element( "div", class => "formfieldname" );

		# Field name should have a star next to it if it is required
		# special case for booleans - even if they're required it
		# dosn't make much sense to highlight them.	

		$div->appendChild( 
			$self->makeText( $field->display_name( $self ) ) );
		if( $field->isRequired() && !$field->is_type( "boolean" ) )
		{
			$span = $self->make_element( 
					"span", 
					class => "requiredstar" );	
			$span->appendChild( $self->makeText( "*" ) );	
			$div->appendChild( $self->makeText( " " ) );	
			$div->appendChild( $span );
		}
		$html->appendChild( $div );
	}

	if( $show_help )
	{
		my $help = $field->display_help( $self );

		$div = $self->make_element( "div", class => "formfieldhelp" );

		$div->appendChild( 
			$self->makeText( $field->display_help( $self ) ) );
		$html->appendChild( $div );
	}

	$div = $self->make_element( "div", class => "formfieldinput" );
	$div->appendChild( $field->render_input_field( $self, $value ) );
	$html->appendChild( $div );

	return( $html );
}	

1;

