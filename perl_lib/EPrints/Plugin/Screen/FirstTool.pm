
package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub from
{
	my( $self ) = @_;

	my @tools = ( $self->list_items( "key_tools" ), $self->list_items( "other_tools" ) );
	if( scalar @tools )
	{
		$self->{processor}->{screenid} = substr( $tools[0]->{screen}->{id}, 8 );
		$self->SUPER::from;
	}
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{handle}->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( "no_tools" ) );

	return $chunk;
}

1;

