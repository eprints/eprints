######################################################################
#
# EPrints::Handle::XML
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

B<EPrints::Handle::XML> - XML methods for EPrints::Session

=head1 DESCRIPTION

This module provides additional methods to EPrints::Handle and is not
an object in it's own right.

=over 4

=cut

use strict;

package EPrints::Handle;



######################################################################
=pod

=item $dom = $handle->make_element( $element_name, %attribs )

Return a DOM element with name ename and the specified attributes.

eg. $handle->make_element( "img", src => "/foo.gif", alt => "my pic" )

Will return the DOM object describing:

<img src="/foo.gif" alt="my pic" />

Note that in the call we use "=>" not "=".

=cut
######################################################################

sub make_element
{
	my( $self , $ename , @opts ) = @_;

	my $element = $self->{doc}->createElement( $ename );
	for(my $i = 0; $i < @opts; $i += 2)
	{
		$element->setAttribute( $opts[$i], $opts[$i+1] )
			if defined( $opts[$i+1] );
	}

	return $element;
}


######################################################################
=pod

=item $dom = $handle->make_indent( $width )

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

=item $dom = $handle->make_comment( $text )

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

=item $DOM = $handle->make_text( $text )

Return a DOM object containing the given text. $text should be
UTF-8 encoded.

Characters will be treated as _text_ including < > etc.

eg.

$handle->make_text( "This is <b> an example" );

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

=item $DOM = $handle->make_javascript( $code, %attribs )

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

=item $fragment = $handle->make_doc_fragment

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

######################################################################
=pod

=item $copy_of_node = $handle->clone_for_me( $node, [$deep] )

XML DOM items can only be added to the document which they belong to.

A EPrints::Handle has it's own XML DOM DOcument. 

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


1;
