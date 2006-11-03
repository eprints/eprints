
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
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search" );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	
	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "intro" ) );

	$page->appendChild( $self->render_saved_search_list );

	return $page;
}

sub render_saved_search_list
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $self->{processor}->{user};
	my @saved_searches = $user->get_saved_searches;
	my $ds = $session->get_repository->get_dataset( "saved_search" );

	if( scalar @saved_searches == 0 )
	{
		return $self->html_phrase( "no_searches" );
	}

	my $page = $session->make_doc_fragment;
	my( $table, $tr, $td, $th );
	$table = $session->make_element( 
		"table",
		style => "margin-bottom: 12pt",
		cellpadding => 4,
		cellspacing => 0,
		border => 1 );
	$page->appendChild( $table );
	foreach my $saved_search ( @saved_searches )
	{
		$self->{processor}->{savedsearchid} = $saved_search->get_id;
		$self->{processor}->{savedsearch} = $saved_search;
		my $screen = $self->{session}->plugin( 
			"Screen::User::SavedSearch::View",
			processor=>$self->{processor} );
		$page->appendChild( 
			$session->render_toolbox( 
				$saved_search->render_value( "spec" ),
				$screen->render ) );
	}
	
	return $page;
}
	

1;
