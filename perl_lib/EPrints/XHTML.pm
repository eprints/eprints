######################################################################
#
# EPrints::XHTML
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

B<EPrints::XHTML> - XHTML Module

=head1 SYNOPSIS

	$xhtml = $repo->xhtml;

	$utf8_string = $xhtml->to_xhtml( $dom_node, %opts );

	$xhtml_dom_node = $xhtml->input_field( $name, $value, type => "text" );
	$xhtml_dom_node = $xhtml->hidden_field( $name, $value );
	$xhtml_dom_node = $xhtml->text_area_field( $name, $value, rows => 4 );
	$xhtml_dom_node = $xhtml->form( "get", $url );

	$xhtml_dom_node = $xhtml->data_element( $name, $value, indent => 4 );

	$page = $xhtml->build_page( %opts );

=head1 DESCRIPTION

The XHTML object facilitates the creation of XHTML objects.

=head1 METHODS

=over 4

=cut

package EPrints::XHTML;

use strict;

@EPrints::XHTML::COMPRESS_TAGS = qw/br hr img link input meta/;
%EPrints::XHTML::COMPRESS_TAG = map { $_ => 1 } @EPrints::XHTML::COMPRESS_TAGS;

# $xhtml = new EPrints::XHTML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository ) = @_;

	my $self = bless { repository => $repository }, $class;

	return $self;
}

=item $node = $xhtml->form( $method [, $action] )

Returns an XHTML form. If $action isn't defined uses the current URL.

=cut

sub form
{
	my( $self, $method, $action ) = @_;
	
	$method = lc($method);
	if( !defined $action )
	{
		$action = $self->{repository}->current_url( query => 0 );
	}

	my $form = $self->{repository}->xml->create_element( "form",
		method => $method,
		'accept-charset' => "utf-8",
		action => $action,
		);
	if( $method eq "post" )
	{
		$form->setAttribute( enctype => "multipart/form-data" );
	}

	return $form;
}

=item $node = $xhtml->input_field( $name, $value, %opts )

	$node = $xhtml->input_field( "name", "Bob", type => "text" );

Returns an XHTML input field with name $name and value $value. Specify "noenter" to prevent the form being submitted when the user presses the enter key.

=cut

sub input_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $noenter;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'noenter' )
		{
			(undef, $noenter) = splice(@opts,$i,2);
			last;
		}
	}
	if( $noenter )
	{
		push @opts, onKeyPress => 'return EPJS_block_enter( event )';
	}

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		@opts );
}

=item $node = $xhtml->hidden_field( $name, $value, %opts );

Returns an XHTML hidden input field.

=cut

sub hidden_field
{
	my( $self, $name, $value, @opts ) = @_;

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		id => $name,
		value => $value,
		type => "hidden",
		@opts );
}

=item $node = $xhtml->text_area_field( $name, $value, %opts )

Returns an XHTML textarea input.

=cut

sub text_area_field
{
	my( $self, $name, $value, @opts ) = @_;

	my $node = $self->{repository}->xml->create_element( "textarea",
		name => $name,
		id => $name,
		@opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	return $node;
}

=item $node = $xhtml->data_element( $name, $value, %opts )

Create a new element named $name containing a text node containing $value.

Options:
	indent - amount of whitespace to indent by

=cut

sub data_element
{
	my( $self, $name, $value, @opts ) = @_;

	my $indent;
	for(my $i = 0; $i < @opts; $i+=2)
	{
		if( $opts[$i] eq 'indent' )
		{
			(undef, $indent ) = splice(@opts,$i,2);
			last;
		}
	}

	my $node = $self->{repository}->xml->create_element( $name, @opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	if( defined $indent )
	{
		my $f = $self->{repository}->xml->create_document_fragment;
		$f->appendChild( $self->{repository}->xml->create_text_node(
			"\n"." "x$indent
			) );
		$f->appendChild( $node );
		return $f;
	}

	return $node;
}

=item $utf8_string = $xhtml->to_xhtml( $node, %opts )

Returns $node as valid XHTML.

=cut

sub to_xhtml
{
	my( $self, $node, %opts ) = @_;

	my $xml = $self->{repository}->xml;

	my @n = ();
	if( $xml->is( $node, "Element" ) )
	{
		my $tagname = $node->localName; # ignore prefixes

		$tagname = lc($tagname);

		push @n, '<', $tagname;
		my $nnm = $node->attributes;
		my $seen = {};

		if( $tagname eq "html" )
		{
			push @n, ' xmlns="http://www.w3.org/1999/xhtml"';
		}

		foreach my $i ( 0..$nnm->length-1 )
		{
			my $attr = $nnm->item($i);
			# strip all namespace definitions
			next if $attr->nodeName =~ /^xmlns/;
			my $name = $attr->localName;

			next if( exists $seen->{$name} );
			$seen->{$name} = 1;

			my $value = $attr->nodeValue;
			utf8::decode($value) unless utf8::is_utf8($value);
			$value =~ s/&/&amp;/g;
			$value =~ s/</&lt;/g;
			$value =~ s/>/&gt;/g;
			$value =~ s/"/&quot;/g;
			push @n, ' ', $name, '="', $value, '"';
		}

		if( $node->hasChildNodes )
		{
			push @n, '>';
			foreach my $kid ( $node->childNodes )
			{
				push @n, $self->to_xhtml( $kid, %opts );
			}
			push @n, '</', $tagname, '>';
		}
		elsif( $EPrints::XHTML::COMPRESS_TAG{$tagname} )
		{
			push @n, ' />';
		}
		elsif( $tagname eq "script" )
		{
			push @n, '>// <!-- No script --></', $tagname, '>';
		}
		else
		{
			push @n, '></', $tagname, '>';
		}
	}
	elsif( $xml->is( $node, "DocumentFragment" ) )
	{
		foreach my $kid ( $node->getChildNodes )
		{
			push @n, $self->to_xhtml( $kid, %opts );
		}
	}
	elsif( $xml->is( $node, "Document" ) )
	{
		push @n, $self->to_xhtml( $node->documentElement, %opts );
	}
	elsif( $xml->is( 
			$node, 
			"Text", 
			"Comment",
			"CDATASection", 
			"ProcessingInstruction",
			"EntityReference" ) )
	{
		push @n, $node->toString; 
		utf8::decode($n[$#n]) unless utf8::is_utf8($n[$#n]);
	}
	else
	{
		print STDERR "EPrints::XHTML: Not sure how to turn node type ".ref($node)." into XHTML.\n";
	}

	return wantarray ? @n : join('', @n);
}

######################################################################
=pod

=back

=cut
######################################################################

1;
