
package EPrints::Plugin::Screen::User::Staff::Edit;

use EPrints::Plugin::Screen::User::Edit;

@ISA = ( 'EPrints::Plugin::Screen::User::Edit' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ stop save next prev /];

	$self->{appears} = [
		{
			place => "user_actions",
			position => 1000,
		}
	];

	$self->{staff} = 1;

	return $self;
}

sub workflow
{
	my( $self ) = @_;

	return $self->SUPER::workflow( 1 );
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/staff/edit" );
}



1;

