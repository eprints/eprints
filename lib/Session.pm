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
			die "Can't load site module for URL: ".$self->{query}->url();
		}
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
		$self->failure( $self->phrase( "H:fail_db_connect" ) );
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

sub newPage
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->{lang}->getID;
	}

	$self->{page} = new XML::DOM::Document;

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
	
	my $message_body = "msg_at".gmtime( time );
	$message_body .= "\n\n$message\n";

	EPrints::Mailer::send_mail(
		$self,
		 "site_admin" ,
		$self->{site}->{admin},
		$subject,
		$message_body );
}

sub HTMLPhrase
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

sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	foreach( keys %inserts )
	{
		$inserts{$_} = $self->makeText( $_ );
	}
        my @callinfo = caller();
        $callinfo[1] =~ m#[^/]+$#;

        my $r = $self->{lang}->file_phrase( $&, $phraseid, \%inserts , $self);

	return $self->treeToUTF8( $r );
}

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
		$string = latin1("*").$string.latin("*");
	}

	return $string;
	
}

sub treeToXHTML
{
	my( $self, $node ) = @_;

	return $node;
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

	$r->content_type( 'text/html' );

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
			$opt->setAttribute( "selected" , undef );
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
				name => "submit",
				value => $_ ) );
		$frag->appendChild( $self->makeText( latin1(" ") ) );
	}

	return( $frag );
}

# $text is a UTF8 String!
sub makeText
{
	my( $self , $text ) = @_;

	return $self->{page}->createTextNode( $text );
}

sub makeDocFragment
{
	my( $self ) = @_;

	return $self->{page}->createDocumentFragment;
}

sub makeGetForm
{
	my( $self, $dest ) = @_;
	
	my $form = $self->{page}->createElement( "form" );
	$form->setAttribute( "method", "get" );
	$dest = $ENV{SCRIPT_NAME} if( !defined $dest );
	$form->setAttribute( "action", $dest );
	return $form;
}

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

sub takeOwnership
{
	my( $self , $domnode ) = @_;

	$domnode->setOwnerDocument( $self->{page} );
}

sub buildPage
{
	my( $self, $title, $mainbit ) = @_;
	
	$self->takeOwnership( $mainbit );
	foreach( $self->{page}->getElementsByTagName( "titlehere" , 1 ) )
	{
		my $element = $self->{page}->createTextNode( $title );
		$_->getParentNode()->replaceChild( $element, $_ );
	}
	foreach( $self->{page}->getElementsByTagName( "pagehere" , 1 ) )
	{
		$_->getParentNode()->replaceChild( $mainbit, $_ );
	}
}

sub sendPage
{
	my( $self, %httpopts ) = @_;
	$self->sendHTTPHeader( %httpopts );
	print $self->{page}->toString;
}

sub pageToFile
{
	my( $self , $filename ) = @_;

	$self->{page}->printToFile( $filename );

}

sub setPage
{
	my( $self, $newhtml ) = @_;
	
	my $html = ($self->{page}->getElementsByTagName( "html" ))[0];
	$self->{page}->removeChild( $html );
	$self->{page}->appendChild( $newhtml );
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


		

1;
