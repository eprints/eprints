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

# CGI scripts must be no-cache. Hmmm.

package EPrints::Session;

use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Language;
use EPrints::Site;
use Unicode::String qw(utf8 latin1);


use XML::DOM;
use XML::Parser;

use strict;
#require 'sys/syscall.ph';

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

	my $langcookie = $self->{query}->cookie( $self->{site}->get_conf( "lang_cookie_name") );
	if( defined $langcookie && !defined $EPrints::Site::General::languages{ $langcookie } )
	{
		$langcookie = undef;
	}
	$self->{lang} = EPrints::Language::fetch( $self->{site} , $langcookie );
	
	$self->new_page;

	# Create a database connection
	$self->{database} = EPrints::Database->new( $self );
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		$self->render_error( $self->phrase( "lib/session:fail_db_connect" ) );
	}

#$self->{starttime} = gmtime( time );

	
	$self->{site}->call( "session_init", $self, $offline );

#
#	my @params = $self->{render}->{query}->param();
#	
#	foreach (@params)
#	{
#		my @vals = $self->{render}->{query}->param($_);
#	}
	

	return( $self );
}

## WP1: BAD
sub new_page
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->{lang}->get_id;
	}

	$self->{page} = new XML::DOM::Document;

	XML::DOM::setTagCompression( \&_tag_compression );

	my $doctype = XML::DOM::DocumentType->new(
			"foo", #cjg what's this bit?
			"html",
			"DTD/xhtml1-transitional.dtd",
			"-//W3C//DTD XHTML 1.0 Transitional//EN" );
	$self->take_ownership( $doctype );
	$self->{page}->setDoctype( $doctype );

	my $xmldecl = $self->{page}->createXMLDecl( "1.0", "UTF-8", "yes" );
	$self->{page}->setXMLDecl( $xmldecl );

	my $newpage = $self->{site}->get_conf( "htmlpage" , $langid )->cloneNode( 1 );
	$self->take_ownership( $newpage );
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
	
	my $message_body = "lib/session:msg_at".gmtime( time );
	$message_body .= "\n\n$message\n";

	EPrints::Mailer::send_mail(
		$self,
		 "lib/session:site_admin" ,
		$self->{site}->{admin},
		$subject,
		$message_body );
}

## WP1: BAD
sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
	# $phraseid [ASCII] 
	# %inserts [HASH: ASCII->DOM]
	#
	# returns [DOM]	

        my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );

	return $self->tree_to_xhtml( $r );
}

## WP1: GOOD
sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	foreach( keys %inserts )
	{
		$inserts{$_} = $self->make_text( $inserts{$_} );
		
	}
        my $r = $self->{lang}->phrase( $phraseid, \%inserts , $self);

	return $self->tree_to_utf8( $r );
}

## WP1: BAD
sub tree_to_utf8
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
		$string .= $self->tree_to_utf8( $_ );
	}

	if( $name eq "fallback" )
	{
		$string = latin1("*").$string.latin1("*");
	}

	return $string;
	
}

## WP1: BAD
sub tree_to_xhtml
{
	my( $self, $node ) = @_;

	return $node;
}
	

	

## WP1: BAD
sub get_db
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
sub get_site
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
sub send_http_header
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
			-name    => $self->{site}->get_conf("lang_cookie_name"),
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{site}->get_conf("lang_cookie_domain") );
		$r->header_out( "Set-Cookie"=>$cookie ); 
	}
	$r->send_http_header;
}

## WP1: BAD
sub start_html
{
	my( $self, $title, $langid ) = @_;
die "NOPE";

	$self->send_http_header();

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
	my $html = $self->{site}->get_conf("html_tail")."\n";
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
sub get_url
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


## WP1: BAD
sub get_order_names
{
	my( $self, $dataset ) = @_;
print STDERR "SELF:".join(",",keys %{$self} )."\n";
		
	my %names = ();
	foreach( keys %{$self->{site}->get_conf(
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
		"ordername_".$dataset->to_string()."_".$orderid );
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

sub make_ruler
{
	my( $self ) = @_;

	return $self->make_element( "hr",
		size => 2,
		noshade => "noshade" );
}


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
sub make_action_buttons
{
	my( $self, %buttons ) = @_;

	# cjg default button if none set?
	
	return $self->_make_buttons_aux( "action" , %buttons );
}

sub make_internal_buttons
{
	my( $self, %buttons ) = @_;

	# cjg default button if none set?
	
	return $self->_make_buttons_aux( "internal" , %buttons );
}


sub _make_buttons_aux
{
	my( $self, $btype, %buttons ) = @_;

	my $frag = $self->make_doc_fragment();

	my $button_id;
	foreach $button_id ( keys %buttons )
	{
		$frag->appendChild(
			$self->make_element( "input",
				class => $btype."button",
				type => "submit",
				name => "_".$btype."_".$button_id,
				value => $buttons{$button_id} ) );

		# Some space between butons.
		$frag->appendChild( $self->make_text( latin1(" ") ) );
	}

	return( $frag );
}

# $text is a UTF8 String!
## WP1: BAD
sub make_text
{
	my( $self , $text ) = @_;

	return $self->{page}->createTextNode( $text );
}

## WP1: BAD
sub make_doc_fragment
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
sub take_ownership
{
	my( $self , $domnode ) = @_;

	$domnode->setOwnerDocument( $self->{page} );
}

## WP1: BAD
sub build_page
{
	my( $self, $title, $mainbit ) = @_;
	
	$self->take_ownership( $mainbit );
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
sub send_page
{
	my( $self, %httpopts ) = @_;
	$self->send_http_header( %httpopts );
	print $self->{page}->toString();
	$self->{page}->dispose();
}

## WP1: BAD
sub page_to_file
{
	my( $self , $filename ) = @_;

	$self->{page}->printToFile( $filename );

}

## WP1: BAD
sub set_page
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
sub subject_tree
{
	my( $self, $subject ) = @_;

	my $frag = $self->make_doc_fragment();
	
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

	my $frag = $self->make_doc_fragment();
	my @children = $subject->children;

print "ooooooooooooooooooook: ".(scalar @children)."\n";
print "doin:\n";
print EPrints::Session::render_struct( $subject );
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
			$self->get_site()->get_conf( "server_static" ).
			"/view/".$subject->{subjectid}.".html" );
	}
	else
	{
		$frag = $self->make_doc_fragment();
	}
	

	if( defined $full && $full )
	{
		$frag->appendChild( $self->make_text(
			EPrints::Subject::subject_label( 
						$self,
		                                $subject->{subjectid} ) ) );
	}
	else
	{
		$frag->appendChild( $self->make_text( $subject->{name} ) );
	}
		
	if( $count && $subject->{depositable} eq "TRUE" )
	{
		my $text = $self->make_text( 
			latin1(" (" .$subject->count_eprints( 
				$self->get_site()->get_data_set( "archive" ) ).
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
		$back_to = $self->get_site()->get_conf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
		$back_to_text = "Continue"; #XXX INTL cjg
	}

	if ( $self->{offline} )
	{
		print $self->phrase( 
			"lib/session:some_error",
			sitename=>$self->{session}->{site}->{sitename} );
		print "\n\n";
		print "$error_text\n\n";
	} 
	else
	{
		my( $p, $page, $a );
		$page = $self->make_doc_fragment();

		$p = $self->make_element( "p" );
		$p->appendChild( $self->html_phrase( 
			"some_error",
			sitename => $self->make_text( 
				$self->get_site()->get_conf( "sitename" ) ) ) );
		$page->appendChild( $p );

		$p = $self->make_element( "p" );
		$p->appendChild( $self->make_text( $error_text ) );
		$page->appendChild( $p );

		$p = $self->make_element( "p" );
		$p->appendChild( $self->html_phrase( 
			"lib/session:contact",
			adminemail => $self->make_element( 
				"a",
				href => "mailto:".
					$self->get_site()->get_conf( "admin" ) ),
			sitename => $self->make_text(
				$self->get_site()->get_conf( "sitename" ) ) ) );
		$page->appendChild( $p );
				
		$p = $self->make_element( "p" );
		$a = $self->make_element( 
				"a",
				href => $back_to );
		$a->appendChild( $self->make_text( $back_to_text ) );
		$p->appendChild( $a );
		$page->appendChild( $p );

		$self->build_page(	
			$self->phrase( "lib/session:error_title" ),
			$page );

		$self->send_page();
	}
}

## WP1: GOOD
sub auth_check
{
	my( $self , $resource ) = @_;

	my $user = $self->current_user;

	if( !defined $user )
	{
		$self->render_error( $self->phrase( "lib/session:no_login" ) );
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
		$self->render_error( $self->phrase( "lib/session:no_priv" ) );
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

sub internal_button_pressed
{
	my( $self, $buttonid ) = @_;

	if( defined $buttonid )
	{
		return( defined $self->param( "_internal_".$buttonid ) );
	}

	# Have not yet worked this out?
	if( !defined $self->{internalbuttonpressed} )
	{
		my $p;
		# $p = string
		
		$self->{internalbuttonpressed} = 0;

		foreach $p ( $self->param() )
		{
			if( $p =~ m/^_internal/ )
			{
				$self->{internalbuttonpressed} = 1;
				last;
			}

		}	
	}

	return $self->{internalbuttonpressed};
}

sub get_action_button
{
	my( $self ) = @_;

	my $p;
	# $p = string
	foreach $p ( $self->param() )
	{
		if( $p =~ m/^_action_/ )
		{
			return substr($p,8);
		}
	}

	return undef;
}

######################################################################
#
# render_form( $fields,              #array_ref
#              $values,              #hash_ref
#              $show_names,
#              $show_help,
#              $action_buttons,      #array_ref
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
#  If $action_buttons isn't passed in (or is undefined), a simple
#  default "Submit" button is slapped on.
#
#  $dest should contain the URL of the destination
#
######################################################################

## WP1: BAD
sub render_form
{
	my( $self, $fields, $values, $show_names, $show_help, $action_buttons,
	    $hidden_fields, $dest ) = @_;

print STDERR EPrints::Session::render_struct( $values );

	my $query = $self->{query};

	my( $form );

	$form =	$self->make_form( "post", $dest );

	my $field;	
	foreach $field (@$fields)
	{
		$form->appendChild( $self->render_form_field( 
					     $field,
		                             $values->{$field->get_name()},
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

	$form->appendChild( $self->make_action_buttons( %{$action_buttons} ) );

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

	$html = $self->make_doc_fragment();

	if( $show_names )
	{
		$div = $self->make_element( "div", class => "formfieldname" );

		# Field name should have a star next to it if it is required
		# special case for booleans - even if they're required it
		# dosn't make much sense to highlight them.	

		$div->appendChild( 
			$self->make_text( $field->display_name( $self ) ) );

		if( $field->get_property( "required" ) && !$field->is_type( "boolean" ) )
		{
			$span = $self->make_element( 
					"span", 
					class => "requiredstar" );	
			$span->appendChild( $self->make_text( "*" ) );	
			$div->appendChild( $self->make_text( " " ) );	
			$div->appendChild( $span );
		}
		$html->appendChild( $div );
	}

	if( $show_help )
	{
		my $help = $field->display_help( $self );

		$div = $self->make_element( "div", class => "formfieldhelp" );

		$div->appendChild( 
			$self->make_text( $field->display_help( $self ) ) );
		$html->appendChild( $div );
	}

	$div = $self->make_element( "div", class => "formfieldinput" );
	$div->appendChild( $field->render_input_field( $self, $value ) );
	$html->appendChild( $div );

	return( $html );
}	

######################################################################
#
# $text = render_struct( $ref, $depth )
#
#  Renders a reference into a human readable tree.
#
######################################################################


## WP1: BAD
sub render_struct
{
	my( $ref , $depth , %done) = @_;

	$depth = 0 if ( !defined $depth );
	my $text = "";
	my $type = "";

	if ( !defined $ref )
	{
		$text = "  "x$depth;
		$text.= "[undef]\n";
		return $text;
	}
	
	if ( defined $done{$ref} )
	{
		$text = "  "x$depth;
		$text.= "[LOOP]\n";
		return $text;
	}

	$done{$ref} = 1;
	
	$type = ref( $ref );
	
	if( $type eq "" )
	{
		$text.= "  "x$depth;
		$text.= "\"$ref\"\n";
		return $text;
	}

	if( $type eq "SCALAR" )
	{
		$text.= "  "x$depth;
		$text.= "SCALAR: \"$ref\"\n";
		return $text;
	}

	if ( $type eq "ARRAY" )
	{
		my @bits = @{$ref};
		$text.= "  "x$depth;
		$text.= "ARRAY (".(scalar @bits).")\n";
		foreach( @bits )
		{
			$text.= render_struct( $_ , $depth+1 , %done );
		}
		return $text;
	}

	# HASH or CLASS

	# Hack: I really don't want to see the whole session

	if( $type eq "EPrints::Session" || $type eq "Apache"
		|| $type eq "EPrints::DataSet"  || $type eq "CODE" )
	{
		$text.= "  "x$depth;
		$text.= "$type\n";
		return $text;
	}
print STDERR "=$type=\n";

	my %bits = %{$ref};
	$text.= "  "x$depth;
	$text.= "$type\n";
	foreach( keys %bits )
	{
		$text.= "  "x$depth;
		$text.= " $_=>\n";
		$text.= render_struct( $bits{$_} , $depth+1 , %done );
	}
	return $text;
}

## WP1: BAD
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

# NEEDS REWRITE IF TO BE USED
# PROBABLY BELONGS HERE, THOUGH.
## WP1: BAD
sub get_subjects
{
	my( $self, $session ) = @_;
	
	my @subjects;

	foreach (@{$self->{subjects}})
	{
		my $sub = new EPrints::Subject( $session, $_ );
		
		push @subjects, $sub if( defined $sub );
		
		unless( defined $sub ) 
		{
			$session->get_site()->log( "List contain invalid tag $_" );
		}
	}
	
	return( @subjects );
}

######################################################################
#
# redirect( $url )
#
#  Redirects the browser to $url.
#
######################################################################

## WP1: BAD
sub redirect
{
	my( $self, $url ) = @_;

	# Write HTTP headers if appropriate
	unless( $self->{offline} )
	{
		# For some reason, redirection doesn't work with CGI::Apache.
		# We have to use CGI.
		print $self->{query}->redirect( -uri=>$url );
	}

}


1;

