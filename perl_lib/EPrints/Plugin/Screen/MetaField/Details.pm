package EPrints::Plugin::Screen::MetaField::Details;

use EPrints::Plugin::Screen::Workflow::Details;
@ISA = qw( EPrints::Plugin::Screen::Workflow::Details );

sub edit_screen { "MetaField::Edit" }
sub view_screen { "MetaField::View" }
sub listing_screen { "MetaField::Listing" }
sub can_be_viewed
{
	my( $self ) = @_;

	return $self->{processor}->{dataobj}->isa( "EPrints::DataObj::MetaField" ) && $self->allow( "config/edit/perl" );
}

1;
