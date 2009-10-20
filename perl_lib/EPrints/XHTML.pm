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

	$page = $xhtml->build_page( %opts );

=head1 DESCRIPTION

The XHTML object facilitates the creation of XHTML objects.

=head1 METHODS

=over 4

=cut

package EPrints::XHTML;

use strict;

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
	my( $self, $name, $value, %opts ) = @_;

	if( delete $opts{noenter} )
	{
		$opts{onKeyPress} = "return EPJS_block_enter( event )";
	}

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		value => $value,
		%opts );
}

=item $node = $xhtml->hidden_field( $name, $value, %opts );

Returns an XHTML hidden input field.

=cut

sub hidden_field
{
	my( $self, $name, $value, %opts ) = @_;

	return $self->{repository}->xml->create_element( "input",
		name => $name,
		value => $value,
		type => "hidden",
		%opts );
}

=item $node = $xhtml->text_area_field( $name, $value, %opts );

Returns an XHTML textarea input.

=cut

sub text_area_field
{
	my( $self, $name, $value, %opts ) = @_;

	my $node = $self->{repository}->xml->create_element( "textarea",
		name => $name,
		%opts );
	$node->appendChild( $self->{repository}->xml->create_text_node( $value ) );

	return $node;
}

######################################################################
=pod

=back

=cut
######################################################################

1;
