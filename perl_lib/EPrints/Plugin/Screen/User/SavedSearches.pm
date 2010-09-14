
package EPrints::Plugin::Screen::User::SavedSearches;

use EPrints::Plugin::Screen::User;

@ISA = ( 'EPrints::Plugin::Screen::User' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "key_tools",
			position => 300,
		},
		{
			place => "user_actions",
			position => 200,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search" );
}

sub from
{
	my( $self ) = @_;

	my $url = URI->new( $self->{session}->current_url( path => "cgi", "users/home" ) );
	$url->query_form(	
		screen => "Listing",
		dataset => "saved_search",
	);

	$self->{session}->redirect( $url );
	exit;
}

1;
