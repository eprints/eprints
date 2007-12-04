package EPrints::Plugin::Screen::EPrint::Staff::Details;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Details' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( "eprint/staff/details" );
}

sub edit_screen_id { return "EPrint::Staff::Edit"; }

sub edit_ok
{
	my( $self ) = @_;

	return $self->allow( "eprint/staff/edit" ) & 8;
}



