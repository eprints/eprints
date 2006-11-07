
package EPrints::Plugin::Screen::User::View;

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
			position => 200,
		},
	];

	return $self;
}

sub render
{
	my( $self ) = @_;
	
	my $session = $self->{session};

	my $page = $session->make_doc_fragment();

	my ($data,$title) = $self->{processor}->{user}->render; 

	$page->appendChild( $data );
	
	$page->appendChild( $self->render_action_list( "user_actions", ['userid'] ) );

	return $page;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "user/view" );
}


1;

