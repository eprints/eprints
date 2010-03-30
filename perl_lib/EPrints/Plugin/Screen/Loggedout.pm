package EPrints::Plugin::Screen::Loggedout;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub can_be_viewed { 1 }

sub render
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->{session}->render_message(
		"message",
		$self->html_phrase( "success" )
	) );

	$frag->appendChild( $self->{session}->html_phrase( "general:frontpage_link" ) );

	return $frag;
}

1;
