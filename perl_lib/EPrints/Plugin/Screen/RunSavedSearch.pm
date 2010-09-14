package EPrints::Plugin::Screen::RunSavedSearch;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ /]; 

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "saved_search_item_actions",
			position => 10,
		}
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{dataobj} = $self->{session}->dataset( "saved_search" )->dataobj( $self->{session}->param( "dataobj" ) );

	$self->SUPER::properties_from();
}

sub from
{
	my( $self ) = @_;

	my $saved_search = $self->{processor}->{dataobj};

	my $plugin = $self->{session}->plugin( "Search" );
	my $searchexp = $plugin->thaw( $saved_search->value( "spec" ) );

	if( !defined $searchexp )
	{
		$self->{processor}->add_message( "error", $self->{session}->html_phrase( "lib/saved_search:bad_search" ) );
		$self->SUPER::from;
		return;
	}

	$self->{session}->redirect( $searchexp->search_url );
	exit;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 if !defined $self->{session}->current_user;

	return $self->{session}->current_user->allow( "saved_search/view", $self->{processor}->{dataobj} );
}

# only happens on error
sub render
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

1;
