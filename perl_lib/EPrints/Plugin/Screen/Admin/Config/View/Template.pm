package EPrints::Plugin::Screen::Admin::Config::View::Template;

use EPrints::Plugin::Screen::Admin::Config::View::XML;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::View::XML' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/view/template" );
}

1;
