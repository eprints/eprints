package EPrints::Plugin::Screen::Workflow::Export;

our @ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "dataobj_view_tabs",
			position => 500,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( $self->dataset->id."/export" );
}

sub render
{
	my( $self ) = @_;

	my ($data,$title) = $self->dataobj->render_export_links; 

	my $div = $self->{session}->make_element( "div",class=>"ep_block" );
	$div->appendChild( $data );
	return $div;
}	


1;
