######################################################################
#
# EPrint Session
#
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

# cjg
# - Make sure user is ePrints for sessions
# - Check for df on startup

package EPrints::Session;

use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Language;
use EPrints::Archive;
use Unicode::String qw(utf8 latin1);

use EPrints::DOM;
use XML::Parser;
use Apache;


EPrints::DOM::setTagCompression( \&_tag_compression );


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
	# mode = 1    - We are offline (bin script) param is archiveid
	# mode = 2    - We are offline (auth) param is host and path.	
	my $self = {};
	bless $self, $class;

print STDERR "\n******* NEW SESSION (mode $mode) ******\n";

	$self->{query} = ( $mode==0 ? new CGI() : new CGI( {} ) );


	if( $mode == 0 || !defined $mode )
	{
		my $r=Apache->request();
		$self->{offline} = 0;
		my $hpp=$r->hostname.":".$r->get_server_port.$r->uri;
		$self->{archive} = EPrints::Archive->new_archive_by_host_port_path( $hpp );
		if( !defined $self->{archive} )
		{
			#cjg icky error handler...
			my $r = Apache->request;
			$r->content_type( 'text/html' );
			$r->send_http_header;
			
			print STDERR "xCan't load archive module for URL: ".$self->{query}->url()."\n";

			return undef;
			
		}
	}
	elsif( $mode == 1 )
	{
		$self->{offline} = 1;
		if( !defined $param || $param eq "" )
		{
			print STDERR "No archive id specified.\n";
			return undef;
		}
		$self->{archive} = EPrints::Archive->new_archive_by_id( $param );
		if( !defined $self->{archive} )
		{
			print STDERR "Can't load archive module for: $param\n";
			return undef;
		}
	}
	elsif( $mode == 2 )
	{
		$self->{offline} = 1;
		$self->{archive} = EPrints::Archive->new_archive_by_host_port_path( $param );
		if( !defined $self->{archive} )
		{
			print STDERR "Can't load archive module for URL: $param\n";
			return undef;
		}
	}
	else
	{
		print STDERR "Unknown session mode: $mode\n";
		return undef;
	}

	#### Got Archive Config Module ###

	# Create a database connection
	$self->{database} = EPrints::Database->new( $self );
	
	if( !defined $self->{database} )
	{
		# Database connection failure - noooo!
		# cjg diff err if offline?
		$self->render_error( $self->html_phrase( "lib/session:fail_db_connect" ) );
		return undef;
	}

	# What language is this session in?

	my $langcookie = $self->{query}->cookie( $self->{archive}->get_conf( "lang_cookie_name") );
	if( defined $langcookie && !grep( /^$langcookie$/, @{$self->{archive}->get_conf( "languages" )} ) )
	{
		$langcookie = undef;
	}

	$self->change_lang( $langcookie );
	#really only (cjg) ONLINE mode should have
	#a language set automatically.
	
	$self->new_page();

#$self->{starttime} = gmtime( time );

	
	$self->{archive}->call( "session_init", $self, $self->{offline} );

#
#	my @params = $self->{render}->{query}->param();
#	
#	foreach (@params)
#	{
#		my @vals = $self->{render}->{query}->param($_);
#	}
	

	return( $self );
}

#
# terminate()
#
#  Perform any cleaning up necessary
#

## WP1: BAD
sub terminate
{
	my( $self ) = @_;
	
	$self->{database}->garbage_collect();
	$self->{archive}->call( "session_close", $self );
	$self->{database}->disconnect();
print STDERR "******* END SESSION ******\n\n";

}

#############################################################
#
# LANGUAGE FUNCTIONS
#
#############################################################

sub default_lang_id
{
	my( $self ) = @_;

	return ${$self->{archive}->get_conf( "languages" )}[0];
}

sub change_lang
{
	my( $self, $newlangid ) = @_;

	if( !defined $newlangid )
	{
		$newlangid = $self->default_lang_id();
	}
	$self->{lang} = $self->{archive}->get_language( $newlangid );

	if( !defined $self->{lang} )
	{
		die "Unknown language: $newlangid, can't go on!";
		# cjg (maybe should try english first...?)
	}
}

sub html_phrase
{
	my( $self, $phraseid , %inserts ) = @_;
	# $phraseid [ASCII] 
	# %inserts [HASH: ASCII->DOM]
	#
	# returns [DOM]	

        my $r = $self->{lang}->phrase( $phraseid , \%inserts , $self );

	return $r;
}

sub phrase
{
	my( $self, $phraseid, %inserts ) = @_;

	foreach( keys %inserts )
	{
		$inserts{$_} = $self->make_text( $inserts{$_} );
	}
        my $r = $self->{lang}->phrase( $phraseid, \%inserts , $self);
	return EPrints::Utils::tree_to_utf8( $r, 40 );#cjg so undo this
}

sub get_langid
{
	my( $self ) = @_;

	return $self->{lang}->get_id();
}

#cjg: should be a util?
sub best_language
{
	my( $archive, $lang, %values ) = @_;

	# no options?
	return undef if( scalar keys %values == 0 );

	# The language of the current session is best
	return $values{$lang} if( defined $values{$lang} );

	# The default lanuage of the archive is second best	
	my $defaultlangid = $archive->get_conf( "languages" )->[0];
	return $values{$defaultlangid} if( defined $values{$defaultlangid} );

	# Bit of personal bias: We'll try English before we just
	# pick the first of the heap.
	return $values{en} if( defined $values{en} );

	# Anything is better than nothing.
	my $akey = (keys %values)[0];
	return $values{$akey};
}

sub get_order_names
{
	my( $self, $dataset ) = @_;
		
	my %names = ();
	foreach( keys %{$self->{archive}->get_conf(
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
		"ordername_".$dataset->confid()."_".$orderid );
}


#############################################################
#
# ACCESSOR(sp cjg) FUNCTIONS
#
#############################################################

sub get_db
{
	my( $self ) = @_;
	return $self->{database};
}

sub get_query
{
	my( $self ) = @_;
	return $self->{query};
}

sub get_archive
{
	my( $self ) = @_;
	return $self->{archive};
}

#
# $url = url()
#
#  Returns the URL of the current script
#

sub get_url
{
	my( $self ) = @_;
	
	return( $self->{query}->url() );
}




#############################################################
#
# DOM FUNCTIONS
#
#############################################################

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

# $text is a UTF8 String!
sub make_text
{
	my( $self , $text ) = @_;

	my $textnode = $self->{page}->createTextNode( $text );

	return $textnode;
}

sub make_doc_fragment
{
	my( $self ) = @_;

	return $self->{page}->createDocumentFragment;
}



#############################################################
#
# XHTML FUNCTIONS
#
#############################################################

sub render_ruler
{
	my( $self ) = @_;

	return $self->make_element( "hr",
		size => 2,
		noshade => "noshade" );
}

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

	my $element = $self->make_element( "select" , name => $params{name} );
	if( defined $params{multiple} )
	{
		$element->setAttribute( "multiple" , $params{multiple} );
	}
	my $size = 0;
	if( defined $params{pairs} )
	{
		my $pair;
		foreach $pair ( @{$params{pairs}} )
		{
			$element->appendChild( 
				$self->render_single_option(
					$pair->[0],
					$pair->[1],
					$defaults{$pair->[0]} ) );
			$size++;
		}
	}
	else
	{
		foreach( @{$params{values}} )
		{
			$element->appendChild( 
				$self->render_single_option(
					$_,
					$params{labels}->{$_},
					$defaults{$_} ) );
			$size++;
			
						
		}
	}
	if( defined $params{height} )
	{
		$size = $params{height} if( $params{height} < $size );
		$element->setAttribute( "size" , $size );
	}
	return $element;
}

sub render_single_option
{
	my( $self, $key, $desc, $selected ) = @_;

	my $opt = $self->make_element( "option", value => $key );
	$opt->appendChild( $self->{page}->createTextNode( $desc ) );

	if( $selected )
	{
		$opt->setAttribute( "selected" , "selected" );
	}
	return $opt;
}

sub render_hidden_field
{
	my( $self , $name , $value ) = @_;

# used to grab values from param() if it exists
# but dosn't now. Is that bad? cjg

	return $self->make_element( "input",
		"accept-charset" => "utf-8",
		name => $name,
		value => $value,
		type => "hidden" );
}

sub render_upload_field
{
	my( $self, $name ) = @_;

	my $div = $self->make_element( "div" ); #no class cjg	
	$div->appendChild( $self->make_element(
		"input", 
		name => $name,
		type => "file" ) );
	return $div;
}

sub render_action_buttons
{
	my( $self, %buttons ) = @_;

	# cjg default button if none set?
	
	return $self->_render_buttons_aux( "action" , %buttons );
}

sub render_internal_buttons
{
	my( $self, %buttons ) = @_;

	# cjg default button if none set?
	
	return $self->_render_buttons_aux( "internal" , %buttons );
}


# cjg buttons nead an order... They are done by a hash
sub _render_buttons_aux
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
		$frag->appendChild( $self->make_text( " " ) );
	}

	return( $frag );
}

## (dest is optional)
#cjg "POST" forms must be utf8 and multipart
sub render_form
{
	my( $self, $method, $dest ) = @_;
	
	my $form = $self->{page}->createElement( "form" );
	$form->setAttribute( "method", $method );
	$form->setAttribute( "accept-charset", "utf-8" );
	$dest = $ENV{SCRIPT_NAME} if( !defined $dest );
	$form->setAttribute( "action", $dest );
	$form->setAttribute( "enctype", "multipart/form-data" );
	return $form;
}

sub render_subjects
{
	my( $self, $subject_list, $baseid, $current, $linkmode ) = @_;

#cjg NO SUBJECT_LIST = ALL SUBJECTS under baseid!
	if( !defined $baseid )
	{
		$baseid = $EPrints::Subject::root_subject;
	}

	my %subs = ();
	foreach( @{$subject_list}, $baseid )
	{
		$subs{$_} = EPrints::Subject->new( $self, $_ );
	}

	return $self->_render_subjects_aux( \%subs, $baseid, $current, $linkmode );
}

sub _render_subjects_aux
{
	my( $self, $subjects, $id, $current, $linkmode ) = @_;

	my( $ul, $li, $elementx );
	$ul = $self->make_element( "ul" );
	$li = $self->make_element( "li" );
	$ul->appendChild( $li );

	if( $id eq $current )
	{
		$elementx = $self->make_element( "strong" );
	}
	else
	{
		if( $linkmode == 1 )
		{
			$elementx = $self->make_element( "a", href=>"edit_subject?subjectid=".$id ); 
		}
		elsif( $linkmode == 2 )
		{
			$elementx = $self->make_element( "a", href=>"$id.html" ); 
		}
		else
		{
			$elementx = $self->make_element( "span" );
		}
	}
	$li->appendChild( $elementx );
	$elementx->appendChild( $subjects->{$id}->render() );
	foreach( $subjects->{$id}->children() )
	{
		my $thisid = $_->get_value( "subjectid" );
		next unless( defined $subjects->{$thisid} );
		$li->appendChild( $self->_render_subjects_aux( $subjects, $thisid, $current, $linkmode ) );
	}
	
	return $ul;
}


#
# $xhtml = render_subject_tree( $subject )
#
#  Return HTML for a subject tree for the given subject. If $subject is
#  undef, the root subject is assumed.
#
#  The tree will feature the current tree, the parents up to the root,
#  and all children.
#

#sooo very iffy.cjg
sub render_subject_tree
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
			$self->render_subject_desc( $parent, 1, 0, 1 ) );
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
			$self->render_subject_desc( $subject, 0, 0, 1 ) );
		$ul->appendChild( $li );
		my $newul = $self->make_element( "ul" );
		$ul->appendChild( $newul );
		$ul = $newul;
	}
	
	# Render children
	$ul->appendChild( $self->_render_subject_children( $subject ) );

	return( $frag );
}

#
# $html = _render_subject_children( $subject )
#
#  Recursively render the children of the given subject into HTML lists.
#

sub _render_subject_children
{
	my( $self, $subject ) = @_;

	my $frag = $self->make_doc_fragment();
	my @children = $subject->children;

	if( @children )
	{
		my $ul = $self->make_element( "ul" );
		$frag->appendChild( $ul );
		my $child;	
		foreach $child (@children)
		{
			my $li = $self->make_element( "li" );
			
			$li->appendChild( $self->render_subject_desc( $child, 1, 0, 1 ) );
			$li->appendChild( $self->_render_subject_children( $child ) );
			$ul->appendChild( $li );
		}
		
	}
	
	return( $frag );
}


#
# $xhtml = render_subject_desc( $subject, $link, $full, $count )
#
#  Return the HTML to render the title of $subject. If $link is non-zero,
#  the title is linked to the static subject view. If $full is non-zero,
#  the full name of the subject is given. If $count is non-zero, the
#  number of eprints in that subject is appended in brackets.
#

# cjg icky call!
sub render_subject_desc
{
	my( $self, $subject, $link, $full, $count ) = @_;
	
	my $frag;
	if( $link )
	{
		$frag = $self->make_element(
				"a",
				href=>
			$self->get_archive()->get_conf( "server_static" ).
			"/view/".$subject->{subjectid}.".html" );
	}
	else
	{
		$frag = $self->make_doc_fragment();
	}
	

	if( defined $full && $full )
	{
		$frag->appendChild( $self->make_text(
			EPrints::Subject::subject_label(  #cjg!!
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
				$self->get_archive()->get_dataset( "archive" ) ).
				")" ) );
		$frag->appendChild( $text );
	}
	
	return( $frag );
}


#
# $xhtml = render_error( $error_text, $back_to, $back_to_text )
#
#  Renders an error page with the given error text. A link, with the
#  text $back_to_text, is offered, the destination of this is $back_to,
#  which should take the user somewhere sensible.
#

## WP1: GOOD
sub render_error
{
	my( $self, $error_text, $back_to, $back_to_text ) = @_;
	
	if( !defined $back_to )
	{
		$back_to = $self->get_archive()->get_conf( "frontpage" );
	}
	if( !defined $back_to_text )
	{
 #XXX INTL cjg not DOM
		$back_to_text = $self->make_text( "Continue" );
	}

	if ( $self->{offline} )
	{
		#cjg This should do some word wrap stuff-> similar 
		# to what the mailer should do
		print $self->phrase( "lib/session:some_error" );
		print "\n\n";
		print "$error_text\n\n"; # now DOM!
		return;
	} 

	my( $p, $page, $a );
	$page = $self->make_doc_fragment();

	$page->appendChild( $self->html_phrase( "lib/session:some_error"));

	$p = $self->make_element( "p" );
	$p->appendChild( $error_text );
	$page->appendChild( $p );

	$page->appendChild( $self->html_phrase( "lib/session:contact" ) );
				
	$p = $self->make_element( "p" );
	$a = $self->make_element( 
			"a",
			href => $back_to );
	$a->appendChild( $back_to_text );
	$p->appendChild( $a );
	$page->appendChild( $p );

	$self->build_page(	
		$self->phrase( "lib/session:error_title" ),
		$page );

	$self->send_page();
}

#
# render_input_form( $fields,              #array_ref
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

## WP1: BAD
sub render_input_form
{
	my( $self, $fields, $values, $show_names, $show_help, $action_buttons,
	    $hidden_fields, $comments, $dest ) = @_;

	my $query = $self->{query};

	my( $form );

#print STDERR "_________RENDER_FORM____________\n";
#use Data::Dumper;
#print STDERR Dumper($values);

	$form =	$self->render_form( "post", $dest );

	my $field;	
	foreach $field (@$fields)
	{
		$form->appendChild( $self->_render_input_form_field( 
					     $field,
		                             $values->{$field->get_name()},
		                             $show_names,
		                             $show_help,
		                             $comments->{$field->get_name()} ) );
	}

	# Hidden field, so caller can tell whether or not anything's
	# been POSTed
	$form->appendChild( $self->render_hidden_field( "_seen", "true" ) );

	if( defined $hidden_fields )
	{
		foreach (keys %{$hidden_fields})
		{
			$form->appendChild( $self->render_hidden_field( 
						$_, 
						$hidden_fields->{$_} ) );
		}
	}

	$form->appendChild( $self->render_action_buttons( %{$action_buttons} ) );

	return $form;
}


sub _render_input_form_field
{
	my( $self, $field, $value, $show_names, $show_help, $comment ) = @_;
	
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

	if( defined $comment )
	{
		$div = $self->make_element( 
			"div", 
			class => "formfieldcomment" );
		$div->appendChild( $comment );
		$html->appendChild( $div );
	}

	if( substr( $self->get_internal_button(), 0, length($field->get_name())+1 ) eq $field->get_name()."_" ) 
	{
		my $a = $self->make_element( "a", name=>"t" );
		$a->appendChild( $html );
		$html = $a;
	}
				
	return( $html );
}	













#############################################################
#
# CURRENT XHTML PAGE FUNCTIONS
#
#############################################################

sub take_ownership
{
	my( $self , $domnode ) = @_;
	$domnode->setOwnerDocument( $self->{page} );
}

sub build_page
{
	my( $self, $title, $mainbit ) = @_;
	
	print STDERR "BUILDPAGE go!\n";	
#cjg Could be different eg. <EPRINTSHOOK type="title" />	
#cjg Could be different eg. <EPRINTSHOOK type="page" />	
#cjg Could be different eg. <EPRINTSHOOK type="topofpage" />	
#cjg would only require one recursive run through, not lots.
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
	foreach $node ( $self->{page}->getElementsByTagName( "topofpage" , 1 ) )
	{
		my $topofpage;
		if( $self->internal_button_pressed() )
		{
			$topofpage = $self->make_doc_fragment();
		}
		else
		{
			$topofpage = $self->make_element( "a", name=>"t" );
		}
		$node->getParentNode()->replaceChild( $topofpage, $node );
		$node->dispose();
	}
	print STDERR "BUILDPAGE stop!\n";	
}

sub send_page
{
	my( $self, %httpopts ) = @_;
	print STDERR "SENDPAGE go!\n";	
	$self->send_http_header( %httpopts );
	print $self->{page}->toString();
	$self->{page}->dispose();
	print STDERR "SENDPAGE stop!\n";	
}

sub page_to_file
{
	my( $self , $filename ) = @_;

	$self->{page}->printToFile( $filename );

}

sub set_page
{
	my( $self, $newhtml ) = @_;
	
	my $html = ($self->{page}->getElementsByTagName( "html" ))[0];
	$self->{page}->removeChild( $html );
	$self->{page}->appendChild( $newhtml );
	$html->dispose();
}

sub new_page
{
	my( $self , $langid ) = @_;

	if( !defined $langid )
	{
		$langid = $self->{lang}->get_id();
	}

	$self->{page} = new EPrints::DOM::Document();

	my $doctype = $self->{page}->createDocumentType(
			"html",
			"DTD/xhtml1-transitional.dtd",
			"-//W3C//DTD XHTML 1.0 Transitional//EN" );
	$self->{page}->setDoctype( $doctype );

	my $xmldecl = $self->{page}->createXMLDecl( "1.0", "UTF-8", "yes" );
	$self->{page}->setXMLDecl( $xmldecl );
print STDERR "new_page:$langid\n";
	my $html = $self->{archive}->get_template( $langid )->cloneNode( 1 );
	$self->take_ownership( $html );
	$self->{page}->appendChild( $html );

}


sub _tag_compression
{
	my ($tag, $elem) = @_;

	# Print empty br, hr and img tags like this: <br />
	return 2 if $tag =~ /^(br|hr|img|input)$/;
	
	# Print other empty tags like this: <empty></empty>
	return 1;
}












###########################################################
#
# FUNCTIONS WHICH HANDLE INPUT FROM THE USER, BROWSER AND
# APACHE
#
###########################################################




#
# $param = param( $name )
#
#  Return a query parameter.
#

## WP1: BAD
sub param
{
	my( $self, $name ) = @_;

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

# $bool = have_parameters()
#
#  Return true if the current script had any parameters (POST or GET)
#

## WP1: BAD
sub have_parameters
{
	my( $self ) = @_;
	
	my @names = $self->{query}->param();

	return( scalar @names > 0 );
}





## WP1: GOOD
sub auth_check
{
	my( $self , $resource ) = @_;

	my $user = $self->current_user;

	if( !defined $user )
	{
		$self->render_error( $self->html_phrase( "lib/session:no_login" ) );
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
		$self->render_error( $self->html_phrase( "lib/session:no_priv" ) );
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
				EPrints::User::user_with_username( $self, $username );
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
			$self->{internalbutton} = substr($p,10);
			return $self->{internalbutton};
		}
	}

	$self->{internalbutton} = "";
	return $self->{internalbutton};
}

###########################################################
#
# OTHER FUNCTIONS
#
###########################################################

sub get_citation_spec
{
	my( $self, $ctype ) = @_;

	my $citespec = $self->{archive}->get_citation_spec( $self->{lang}->get_id(), $ctype );
	if( !defined $citespec )
	{
		return $self->make_text( "Error: Unknown Citation Style \"$ctype\"" );
	}
	my $cite = $citespec->cloneNode( 1 );
	$self->take_ownership( $cite );

	return $cite;
}


#
# $text = render_struct( $ref, $depth )
#
#  Renders a reference into a human readable tree.
#


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
		$text.= "[ (length=".(scalar @bits).")\n";
		foreach( @bits )
		{
			$text.= render_struct( $_ , $depth+1 , %done );
		}
		$text.= "  "x$depth;
		$text.= "]\n";
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

	my %bits = %{$ref};
	$text.= "  "x$depth;
	$text.= "{ $type\n";
	foreach( keys %bits )
	{
		$text.= "  "x$depth;
		$text.= " $_=>\n";
		$text.= render_struct( $bits{$_} , $depth+1 , %done );
	}
	$text.= "  "x$depth;
	$text.= "}\n";
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


# NEEDS REWRITE IF TO BE USED
# PROBABLY BELONGS HERE, THOUGH.
# cjg Nah, ask the subject class - remove this
## WP1: BAD
# sub get_subjects
# {
	# my( $self, $session ) = @_;
	# 
	# my @subjects;
	# my $subject;
	# foreach $subject (@{$self->{subjects}})
	# {
		# my $sub = new EPrints::Subject( $session, $subject );
		# 
		# push @subjects, $sub if( defined $sub );
		# 
		# unless( defined $sub ) 
		# {
			# $session->get_archive()->log( "List contain invalid tag $subject" );
		# }
	# }
	# 
	# return( @subjects );
# }

#
# redirect( $url )
#
#  Redirects the browser to $url.
#

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

#
# mail_administrator( $subject, $message )
#
#  Sends a mail to the archive administrator with the given subject and
#  message body.
#

## WP1: BAD
sub mail_administrator
{
	my( $self,   $subjectid, $messageid, %inserts ) = @_;
	#   Session, string,     string,     string->DOM

	# Mail the admin in the default language
	my $langid = $self->{archive}->get_conf( "languages" )->[0];
	my $lang = $self->{archive}->get_language( $langid );

	return EPrints::Utils::send_mail(
		$self->{archive},
		$langid,
		$lang->phrase( "lib/session:archive_admin", {}, $self ),
		$self->{archive}->get_conf( "adminemail" ),
		EPrints::Utils::tree_to_utf8( $lang->phrase( $subjectid, {}, $self ) ),
		$lang->phrase( $messageid, \%inserts, $self ), 
		$lang->phrase( "mail_sig", {}, $self ) ); 
}

sub send_http_header
{
	my( $self, %opts ) = @_;

	# Write HTTP headers if appropriate
	if( $self->{offline} )
	{
		$self->{archive}->log( "Attempt to send HTTP Header while offline" );
		return;
	}

	my $r = Apache->request;
	$r->content_type( 'text/html; charset=UTF-8' );
	$r->header_out( "Cache-Control"=>"no-cache, must-revalidate" );
	$r->header_out( "Pragma"=>"no-cache" );

	if( defined $opts{lang} )
	{
		my $cookie = $self->{query}->cookie(
			-name    => $self->{archive}->get_conf("lang_cookie_name"),
			-path    => "/",
			-value   => $opts{lang},
			-expires => "+10y", # really long time
			-domain  => $self->{archive}->get_conf("lang_cookie_domain") );
		$r->header_out( "Set-Cookie"=>$cookie ); 
	}
	$r->send_http_header;
}





########################################################################
# DEPRECATED AND DOOMED
########################################################################

## WP1: BAD
sub start_html
{
	my( $self, $title, $langid ) = @_;
die "NOPE";

	$self->send_http_header();

	my $html = "<BODY> begin here ";

	return( $html );
}

## WP1: BAD
sub end_html
{
	my( $self ) = @_;
die "NOPE";
	
	# End of HTML gubbins
	my $html = $self->{archive}->get_conf("html_tail")."\n";
	$html .= $self->{query}->end_html;

	return( $html );
}

## WP1: BAD
sub end_form
{
die "NOPE";
	my( $self ) = @_;
	return( $self->{query}->endform );
}

## WP1: BAD
sub bomb
{	
	my( $notabort ) = @_;
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
	exit unless $notabort;
}

1;

