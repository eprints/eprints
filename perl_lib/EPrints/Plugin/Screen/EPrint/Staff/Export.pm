package EPrints::Plugin::Screen::EPrint::Staff::Export;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = "view/eprint/export_staff";

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 500,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint/staff/export" );
}

sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render_export_links(1); 

	return $data;
}	


1;
