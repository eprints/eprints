
package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;


sub from
{
	my( $self ) = @_;

	my $screenid = $self->param( "default" );
	$screenid = "Items" if !defined $screenid;
	my $screen = $self->{session}->plugin( "Screen::$screenid" );
	if( defined $screen )
	{
		$self->{processor}->{screenid} = $screenid;
		$self->SUPER::from;
	}
}

sub render
{
	my( $self ) = @_;

	my $chunk = $self->{session}->make_doc_fragment;

	$chunk->appendChild( $self->html_phrase( "no_tools" ) );

	return $chunk;
}

1;

