package EPrints::Plugin::Screen::NewDataobj;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ create /];

	$self->{appears} = [
		{
			place => "dataobj_tools",
			action => "create",
			position => 100,
		}
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	my $processor = $self->{processor};
	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" );

	my $dataset = $session->dataset( $datasetid );
	if( !defined $dataset )
	{
		$processor->{screenid} = "Error";
		$processor->add_message( "error", $session->html_phrase(
			"lib/history:no_such_item",
			datasetid=>$session->make_text( $datasetid ),
			objectid=>$session->make_text( "" ) ) );
		return;
	}

	$processor->{"dataset"} = $dataset;

	$self->SUPER::properties_from;
}

sub allow_create
{
	my ( $self ) = @_;

	return $self->allow( $self->{processor}->{dataset}->id."/create" );
}

sub action_create
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{dataset};

	my $epdata = {};

	if( defined $ds->field( "userid" ) )
	{
		my $user = $self->{session}->current_user;
		$epdata->{userid} = $user->id;
	}

	$self->{processor}->{dataobj} = $ds->create_dataobj( $epdata );

	if( !defined $self->{processor}->{dataobj} )
	{
		my $db_error = $self->{session}->get_database->error;
		$self->{processor}->{session}->get_repository->log( "Database Error: $db_error" );
		$self->{processor}->add_message( 
			"error",
			$self->html_phrase( "db_error" ) );
		return;
	}

	$self->{processor}->{screenid} = "Workflow::Edit";
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $url = URI->new($self->{processor}->{url});
	$url->query_form( 
		screen => $self->{processor}->{screenid},
		dataset => $self->{processor}->{dataset}->id,
		_action_create => 1
		);

	$session->redirect( $url );
	$session->terminate();
	exit(0);
}


1;
