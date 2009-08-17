package EPrints::Plugin::Screen::User::SavedSearch::Remove;

our @ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "saved_search_actions",
			position => 500,
		}
	];
	
	$self->{actions} = [qw/ remove cancel /];

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/remove" );
}

sub render
{
	my( $self ) = @_;

	my $div = $self->{handle}->make_element( "div", class=>"ep_block" );

	$div->appendChild( $self->html_phrase("sure_delete", 
		title=>$self->{processor}->{savedsearch}->render_description() ) );

	my %buttons = (
		cancel => $self->phrase( "cancel" ),
		remove => $self->phrase( "remove" ),
		_order => [ "remove", "cancel" ]
	);

	my $form= $self->render_form;
	$form->appendChild( $self->{handle}->render_action_buttons( %buttons ) );
	$div->appendChild( $form );

	return( $div );
}	

sub allow_remove
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_cancel
{
	my( $self ) = @_;

	return 1;
}

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "User::SavedSearches";
}

sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "User::SavedSearches";

	if( !$self->{processor}->{savedsearch}->remove )
	{
		my $db_error = $self->{handle}->get_database->error;
		$self->{handle}->get_repository->log( "DB error removing Saved Search ".$self->{processor}->{savedsearch}->get_id.": $db_error" );
		$self->{processor}->add_message( "message", $self->html_phrase( "item_not_removed" ) );
		return;
	}

	$self->{processor}->add_message( "message", $self->html_phrase( "item_removed" ) );
}


1;
