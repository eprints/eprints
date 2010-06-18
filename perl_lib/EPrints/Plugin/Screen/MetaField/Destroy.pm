package EPrints::Plugin::Screen::MetaField::Destroy;

use EPrints::Plugin::Screen::Workflow::Destroy;
@ISA = qw( EPrints::Plugin::Screen::Workflow::Destroy );

sub edit_screen { "MetaField::Edit" }
sub view_screen { "MetaField::View" }
sub listing_screen { "MetaField::Listing" }
sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{dataobj}->isa( "EPrints::DataObj::MetaField" ) && $self->allow( "config/edit/perl" );
}

sub action_remove
{
	my( $self ) = @_;

	return if !$self->SUPER::action_remove;

	$self->{processor}->{notes}->{dataset} = $self->{session}->dataset( $self->{processor}->{dataobj}->value( "mfdatasetid" ) );
}

1;
