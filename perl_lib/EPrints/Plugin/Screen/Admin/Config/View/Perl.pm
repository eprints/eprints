package EPrints::Plugin::Screen::Admin::Config::View::Perl;

use EPrints::Plugin::Screen::Admin::Config::View;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::View' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/view/perl" );
}

1;
