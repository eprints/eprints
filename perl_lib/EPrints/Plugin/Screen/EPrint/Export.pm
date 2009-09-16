package EPrints::Plugin::Screen::EPrint::Export;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

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

	return $self->allow( "eprint/export" );
}

sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->{processor}->{eprint}->render_export_links; 

	my $div = $self->{session}->make_element( "div",class=>"ep_block" );
	$div->appendChild( $data );
	return $div;
}	


1;
