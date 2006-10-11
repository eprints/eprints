package EPrints::Plugin::Screen::EPrint::Staff::Details;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint::Details' );

use strict;

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( "eprint/staff/details" );
}

sub _render_name_maybe_with_link
{
	my( $self, $eprint, $field ) = @_;

	my $r_name = $field->render_name( $eprint->{session} );

	return $r_name unless $self->allow( "eprint/staff/edit" ) & 8;

	my $name = $field->get_name;

	my $workflow = $self->workflow;
	my $stage = $workflow->{field_stages}->{$name};
	return $r_name if( !defined $stage );

	my $url = "?eprintid=".$eprint->get_id."&screen=EPrint::Staff::Edit&stage=$stage#$name";
	my $link = $eprint->{session}->render_link( $url );
	$link->appendChild( $r_name );
	return $link;
}


