
package EPrints::Plugin::Screen::Subscription::Edit;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub properties_from
{
	my( $self ) = @_;

	$self->{processor}->{subid} = $self->{session}->param( "subid" );
	$self->{processor}->{subscription} = new EPrints::DataObj::Subscription( $self->{session}, $self->{processor}->{subid} );

	if( !defined $self->{processor}->{subscription} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", $self->html_phrase( "cant_find_it",
			id=>$self->{session}->make_text( $self->{processor}->{subid} ) ) );
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

	return $self->allow( "subscription/edit" );
}


sub action_save
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $subscribe_ds = $session->get_repository->get_dataset( "subscription" );

	$self->{processor}->{subscription}->set_value( 
		"spec",
		$subscribe_ds->get_field( "spec" )->form_value(
			$session ) );
	$self->{processor}->{subscription}->set_value( 
		"frequency",
		$subscribe_ds->get_field( 
			"frequency" )->form_value(
				$session ) );
	$self->{processor}->{subscription}->set_value( 
		"mailempty",
		$subscribe_ds->get_field( 
			"mailempty" )->form_value(
				$session ) );

	$self->{processor}->{subscription}->commit();

	# change screen
	$self->{processor}->{screenid} = "Subscription::List";
}


sub action_remove
{
	my( $self ) = @_;

	$self->{processor}->{subscription}->remove;
	delete $self->{processor}->{subscription};
	delete $self->{processor}->{subid};

	# change screen
	$self->{processor}->{screenid} = "Subscription::List";
}	

sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "Subscription::List";
}


sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;
	my $subscribe_ds = $session->get_repository->get_dataset( "subscription" );
	
	my $page = $session->make_doc_fragment;

	$page->appendChild( $self->html_phrase( "edit_blurb" ) );

	$page->appendChild(
		$session->render_input_form( 
			fields => [
				$subscribe_ds->get_field( "spec" ),
				$subscribe_ds->get_field( "frequency" ),
				$subscribe_ds->get_field( "mailempty" )
			],
			values => $self->{processor}->{subscription}->get_data,
			show_names => 1,
			show_help => 1,
			hidden_fields => {
				subid => $self->{processor}->{subscription}->get_value( "subid" ),
				screen => "Subscription::Edit",
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
