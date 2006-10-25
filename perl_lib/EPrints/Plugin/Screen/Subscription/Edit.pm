
package EPrints::Plugin::Screen::SavedSearch::Edit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{saved_search_id} = $self->{session}->param( "saved_search_id" );
	$self->{processor}->{saved_search} = new EPrints::DataObj::SavedSearch( 
		$self->{session}, 
		$self->{processor}->{saved_search_id} );

	if( !defined $self->{processor}->{saved_search} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase( "cant_find_it",
				id => $self->{session}->make_text( 
					$self->{processor}->{saved_search_id} ) ) );
		return;
	}

	$self->SUPER::properties_from;
}

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ cancel remove save /];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/edit" );
}


sub action_save
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $ds = $session->get_repository->get_dataset( "saved_search" );

	$self->{processor}->{saved_search}->set_value( 
		"spec",
		$ds->get_field( "spec" )->form_value(
			$session ) );
	$self->{processor}->{saved_search}->set_value( 
		"frequency",
		$ds->get_field( 
			"frequency" )->form_value(
				$session ) );
	$self->{processor}->{saved_search}->set_value( 
		"mailempty",
		$ds->get_field( 
			"mailempty" )->form_value(
				$session ) );

	$self->{processor}->{saved_search}->commit;

	# change screen
	$self->{processor}->{screenid} = "SavedSearch::List";
}


sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{saved_search}->remove;
	delete $self->{processor}->{saved_search};
	delete $self->{processor}->{saved_search_id};

	# change screen
	$self->{processor}->{screenid} = "SavedSearch::List";
}	

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "SavedSearch::List";
}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	my $ds = $session->get_repository->get_dataset( "saved_search" );
	
	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "edit_blurb" ) );

	$page->appendChild(
		$session->render_input_form( 
			fields => [
				$ds->get_field( "spec" ),
				$ds->get_field( "frequency" ),
				$ds->get_field( "mailempty" )
			],
			values => $self->{processor}->{saved_search}->get_data,
			show_names => 1,
			show_help => 1,
			hidden_fields => {
				searchid => $self->{processor}->{saved_search}->get_value( "id" ),
				screen => "SavedSearch::Edit",
			},
			default_action => "save",
			buttons => {
				cancel => $self->phrase( "cancel" ),
				save => $self->phrase( "save" ),
			}
		) );
			
	return $page;
}
	

1;
