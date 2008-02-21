package EPrints::Plugin::Screen::Admin::ManageFields;

@ISA = ( 'EPrints::Plugin::Screen' );

our %FORBIDDEN = ( user => 1 ); # Otherwise they'll break themselves!

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ remove_field add_field cancel /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions", 
			position => 2000, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/remove_field" );
}

sub allow_cancel
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_add_field
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub allow_remove_field
{
	my( $self ) = @_;

	return $self->can_be_viewed;
}

sub action_cancel {}

sub action_add_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $fieldid = $session->param( "field" ) or return;
	my $confirm = $session->param( "confirm" );

	unless( $self->can_change_field( $datasetid, $fieldid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
		return;
	}

	unless( $confirm )
	{
		my $form = $session->render_input_form(
			fields => [],
			buttons => { add_field => $self->phrase( "confirm" ), cancel => $self->phrase( "cancel" ), _order => [qw( add_field cancel )] },
		);
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "confirm_add",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
				confirm_button => $form,
			) );
		$form->appendChild( $self->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
		$form->appendChild( $self->render_hidden_field( "dataset", $datasetid ) );
		$form->appendChild( $self->render_hidden_field( "field", $fieldid ) );
		$form->appendChild( $self->render_hidden_field( "confirm", 1 ) );
		return;
	}

	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $field = $dataset->get_field( $fieldid );

	$session->get_database->add_field( $dataset, $field );

	$self->{processor}->add_message( "message",
		$self->html_phrase( "added_field",
			datasetid => $session->make_text( $datasetid ),
			fieldid => $session->make_text( $fieldid )
		) );
}	

sub action_remove_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $fieldid = $session->param( "field" ) or return;
	my $confirm = $session->param( "confirm" );

	unless( $self->can_change_field( $datasetid, $fieldid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
			) );
		return;
	}

	unless( $confirm )
	{
		my $form = $session->render_input_form(
			fields => [],
			buttons => { remove_field => $self->phrase( "confirm" ), cancel => $self->phrase( "cancel" ), _order => [qw( remove_field cancel )] },
		);
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "confirm_remove",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
				confirm_button => $form,
			) );
		$form->appendChild( $self->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
		$form->appendChild( $self->render_hidden_field( "dataset", $datasetid ) );
		$form->appendChild( $self->render_hidden_field( "field", $fieldid ) );
		$form->appendChild( $self->render_hidden_field( "confirm", 1 ) );
		return;
	}

	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $field = $dataset->get_field( $fieldid );

	$session->get_database->remove_field( $dataset, $field );

	$self->{processor}->add_message( "message",
		$self->html_phrase( "removed_field",
			datasetid => $session->make_text( $datasetid ),
			fieldid => $session->make_text( $fieldid )
		) );
}	

sub can_change_field
{
	my( $self, $datasetid, $fieldid ) = @_;

	return if $FORBIDDEN{$datasetid};

	my $fields = $self->{session}->get_repository->get_conf( "fields" );

	return 0 unless exists $fields->{$datasetid};

	for(@{$fields->{$datasetid}})
	{
		return 1 if $_->{name} eq $fieldid;
	}

	return 0;
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $url = URI->new($self->SUPER::redirect_to_me_url);
	$url->query_form( $url->query_form,
		map { $_ => $self->{session}->param( $_ ) } qw( dataset field confirm ) );

	return "$url";
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $fields = $session->get_repository->get_conf( "fields" );

	my @datasets = grep { !$FORBIDDEN{$_} } sort { $a cmp $b } keys %$fields;

	my $url = URI->new("");
	$url->query_form(
		screen => $self->{processor}->{screenid},
	);

	$html->appendChild( $self->html_phrase( "datasets" ) );

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $datasetid (@datasets)
	{
		my $u = $url->clone;
		$u->query_form( $u->query_form, dataset => $datasetid );
		my $link = $session->render_link( $u );
		$table->appendChild(
			$session->render_row(
				$session->html_phrase( "datasetname_$datasetid" ),
				$session->html_phrase( "datasethelp_$datasetid" ),
				$link,
			) );
		$link->appendChild( $self->html_phrase( "edit_dataset",
			datasetid => $session->make_text( $datasetid )
			) );
	}

	my $datasetid = $session->param( "dataset" );

	if( $datasetid )
	{
		my $dataset = $session->get_repository->get_dataset( $datasetid );

		if( $dataset )
		{
			$html->appendChild( $self->render_dataset( $dataset ) );
		}
		else
		{
			$self->{processor}->add_message( "error",
				$self->phrase( "invalid_datasetid" )
			);
		}
	}

	return $html;
}

sub render_dataset
{
	my( $self, $dataset ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $datasetid = $dataset->confid;

	my $fields = $session->get_repository->get_conf( "fields" );

	$fields = $fields->{$datasetid};

	my $h2 = $session->make_element( "h2" );
	$html->appendChild( $h2 );
	$h2->appendChild( $session->html_phrase( "datasetname_$datasetid" ) );

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $field (sort { $a->{name} cmp $b->{name} } @$fields)
	{
		my $fieldid = $field->{name};
		$field = $dataset->get_field( $fieldid );

		my %buttons;
		if( $session->get_database->has_field( $dataset, $field ) )
		{
			$buttons{remove_field} = $self->phrase( "remove" );
		}
		else
		{
			$buttons{add_field} = $self->phrase( "add" );
		}

		my $form = $session->render_input_form(
			fields => [],
			show_names => 0,
			show_help => 0,
			buttons => \%buttons,
		);

		$table->appendChild(
			$session->render_row(
				$session->make_text( $fieldid ),
				$session->html_phrase( "$datasetid\_fieldname\_$fieldid" ),
				$form
			) );
		$form->appendChild( $self->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
		$form->appendChild( $self->render_hidden_field( "dataset", $datasetid ) );
		$form->appendChild( $self->render_hidden_field( "field", $fieldid ) );
	}

	return $html;
}

sub render_hidden_field
{
	my( $self, $name, $value ) = @_;

	return $self->{session}->make_element(
		"input",
		type => "hidden",
		name => $name,
		value => $value,
	);
}

1;
