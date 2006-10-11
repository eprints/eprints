package EPrints::Plugin::Screen::EPrint::Staff::EditLink;

use EPrints::Plugin::Screen::EPrint::EditLink;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::EditLink' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 400,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/staff/edit" );
}

sub things
{
	my( $self ) = @_;

	return( "EPrint::Staff::Edit", $self->workflow(1) );
}


1;
