package EPrints::Plugin::Screen::Admin::Config::Edit::Workflow;

use EPrints::Plugin::Screen::Admin::Config::Edit::XML;

@ISA = ( 'EPrints::Plugin::Screen::Admin::Config::Edit::XML' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/edit/workflow" );
}

1;
