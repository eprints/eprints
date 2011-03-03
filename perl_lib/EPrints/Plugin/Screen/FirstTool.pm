=head1 NAME

EPrints::Plugin::Screen::FirstTool - the first screen to show

=head1 DESCRIPTION

This plugin is the screen shown by the ScreenProcessor if there is no 'screen' parameter.

This plugin redirects to the "Items" screen by default. To change this use:

	$c->{plugins}->{"Screen::FirstTool"}->{params}->{default} = "Screen::First";

=cut

package EPrints::Plugin::Screen::FirstTool;

use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	my $screenid = $self->param( "default" );
	$screenid = "Items" if !defined $screenid;
	my $screen = $self->{session}->plugin( "Screen::$screenid",
			processor => $self->{processor},
		);
	if( defined $screen )
	{
		$self->{processor}->{screenid} = $screenid;
		$screen->properties_from;
	}
}

sub render
{
	my( $self ) = @_;

	return $self->html_phrase( "no_tools" );
}

1;

