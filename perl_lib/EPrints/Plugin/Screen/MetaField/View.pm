package EPrints::Plugin::Screen::MetaField::View;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ edit_field remove_field new_field delete_field rename_field cancel /]; 
		
	$self->{appears} = [
		{ 
			place => "admin_actions_config", 
			position => 2050, 
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "config/remove_field" );
}

*allow_cancel =
*allow_new_field =
*allow_edit_field =
*allow_remove_field = 
*allow_rename_field = 
*allow_delete_field = \&can_be_viewed;

sub action_cancel {}

sub action_new_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $name = $session->param( "name" ) or return;
	my $metafieldid = "$datasetid.$name";

	my $dataset = $session->get_repository->get_dataset( $datasetid );

	if( $name =~ /[^a-z_]/ )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "bad_name",
				name => $session->make_text( $name )
			)
		);
		return;
	}

	if( !$dataset )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_dataset" )
		);
		return;
	}

	$self->{processor}->{datasetid} = $dataset->confid;

	if( $dataset->has_field( $name ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "field_exists" )
		);
		return;
	}

	my $ds = $session->get_repository->get_dataset( "metafield" );

	if( my $obj = $ds->get_object( $session, $metafieldid ) )
	{
		$self->{processor}->{dataobj} = $obj;
	}
	else
	{
		$self->{processor}->{dataobj} = $ds->create_object( $session, {
			metafieldid => $metafieldid,
			mfdatasetid => $datasetid,
			name => $name,
		});
	}

	if( !$self->{processor}->{dataobj} )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "create_failed" )
		);
		return;
	}

	$self->{processor}->{dataobj_id} = $metafieldid;
	$self->{processor}->{screenid} = "MetaField::Edit";
}	

sub action_edit_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $fieldid = $session->param( "field" ) or return;
	my $confirm = $session->param( "confirm" );
	my $metafieldid = "$datasetid.$fieldid";

	unless( $confirm )
	{
		my $form = $session->render_input_form(
			fields => [],
			buttons => { edit_field => $self->phrase( "confirm" ), cancel => $self->phrase( "cancel" ), _order => [qw( edit_field cancel )] },
		);
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "confirm_edit",
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

	if( !$dataset )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_dataset" )
		);
		return;
	}

	$self->{processor}->{datasetid} = $dataset->confid;

	if( !$dataset->has_field( $fieldid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
			) );
		return;
	}

	my $ds = $session->get_repository->get_dataset( "metafield" );

	if( my $obj = $ds->get_object( $session, $metafieldid ) )
	{
		$self->{processor}->{dataobj} = $obj;
	}

	$self->{processor}->{dataobj_id} = $metafieldid;
	$self->{processor}->{screenid} = "MetaField::Edit";
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

	my $ds = $session->get_repository->get_dataset( "metafield" );
	my $dataset = $session->get_repository->get_dataset( $datasetid );
	my $field = $dataset->get_field( $fieldid );

	my $metafield = $ds->get_object( $session, $datasetid.".".$fieldid );
	if( !$metafield )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_in_metafield",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
		return;
	}

	if( $metafield->get_value( "providence" ) ne "user" )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_user_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
		return;
	}

	$metafield->remove_from_workflow;
	$metafield->move_to_deletion;
	my $ok = EPrints::DataObj::MetaField::save_all( $session );

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "removed_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );

		if( my $plugin = $self->{session}->plugin( "Screen::Admin::Reload" ) )
		{
			my $screenid = $self->{processor}->{screenid};
			$plugin->{processor} = $self->{processor};
			$plugin->action_reload_config;
			$plugin->{processor}->{screenid} = $screenid ;
		}
	}
	else
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "remove_failed",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
	}
}

sub action_delete_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $fieldid = $session->param( "name" ) or return;

	my $ds = $session->get_repository->get_dataset( "metafield" );

	my $obj = $ds->get_object( $session, $datasetid.".".$fieldid );

	if( $obj and $obj->get_value( "mfstatus" ) eq "inbox" )
	{
		$obj->remove;
		$self->{processor}->add_message( "message",
			$self->html_phrase( "deleted_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
	}
	else
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
	}
}

sub action_rename_field
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $datasetid = $session->param( "dataset" ) or return;
	my $fieldid = $session->param( "field" ) or return;
	my $newid = $session->param( "new_name" ) or return;

	return if $fieldid eq $newid;

	unless( $self->can_change_field( $datasetid, $fieldid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
			) );
		return;
	}

	my $ds = $session->get_repository->get_dataset( "metafield" );

	my $metafield = $ds->get_object( $session, $datasetid.".".$fieldid );
	if( !$metafield )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_in_metafield",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
		return;
	}

	if( $metafield->get_value( "providence" ) ne "user" )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_user_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid )
			) );
		return;
	}

	my $dataset = $session->get_repository->get_dataset( $datasetid );

	if( $dataset->has_field( $newid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "field_exists" )
		);
		return;
	}

	my $field = $dataset->get_field( $fieldid );

	# remove the field from the dataset
	$dataset->unregister_field( $field );

	# remove from workflow
	$metafield->remove_from_workflow();

	# rename the metafield object
	$metafield->remove();
	$metafield->set_value( "name", $newid );
	$metafield->set_value( "metafieldid", "$datasetid.$newid" );
	$metafield = $metafield->clone();

	# get the new field object
	my $new_field = $metafield->make_field_object();

	# rename the field in the database
	$session->get_database->rename_field( $dataset, $new_field, $fieldid );

	# register the new field name
	$dataset->register_field( $new_field );

	my $ok = EPrints::DataObj::MetaField::save_all( $session );

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "renamed_field",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
				newid => $session->make_text( $newid ),
			) );

		if( my $plugin = $session->plugin( "Screen::Admin::Reload" ) )
		{
			my $screenid = $self->{processor}->{screenid};
			$plugin->{processor} = $self->{processor};
			$plugin->action_reload_config;
			$plugin->{processor}->{screenid} = $screenid ;
		}
	}
	else
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "rename_failed",
				datasetid => $session->make_text( $datasetid ),
				fieldid => $session->make_text( $fieldid ),
				newid => $session->make_text( $newid ),
			) );
	}
}

sub can_change_field
{
	my( $self, $datasetid, $fieldid ) = @_;

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

	my $datasetid = $self->{processor}->{datasetid} || $self->{session}->param( "dataset" );

	return $self->SUPER::redirect_to_me_url."&dataset=".$datasetid;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $fields = $session->get_repository->get_conf( "fields" );

	my @datasets = $session->get_repository->get_types( "datasets" );

	my $url = URI->new("");
	$url->query_form(
		screen => $self->{processor}->{screenid},
	);

	$html->appendChild( $self->html_phrase( "help" ) );

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

	# user-configured fields
	my @fields = @{
		$session->get_repository->get_conf( "fields", $datasetid ) || []
	};

	# system fields
	push @fields, $dataset->get_object_class->get_system_field_info;

	my $h2 = $session->make_element( "h2" );
	$html->appendChild( $h2 );
	$h2->appendChild( $session->html_phrase( "datasetname_$datasetid" ) );

	$html->appendChild( $self->render_new_form( $dataset ) );

	$table = $session->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $field (sort { $a->{name} cmp $b->{name} } @fields)
	{
		my $fieldid = $field->{name};
		$field = $dataset->get_field( $fieldid );

		if( !defined $field )
		{
			$session->get_repository->log( "Encountered a configured field that wasn't in dataset: $fieldid" );
			next;
		}

		my $actions = $session->make_doc_fragment;

		if( $field->get_property( "providence" ) eq "core" )
		{
			$actions->appendChild( $self->html_phrase( "core_field" ) );
		}
		elsif( $field->get_property( "providence" ) eq "config" )
		{
			$actions->appendChild( $self->html_phrase( "config_field" ) );
		}
		else
		{
			my $form = $session->render_input_form(
				fields => [],
				show_names => 0,
				show_help => 0,
				buttons => {
						edit_field => $self->phrase( "edit" ),
						remove_field => $self->phrase( "remove" ),
						rename_field => $self->phrase( "rename" ),
						_order => [qw( rename_field edit_field remove_field )],
					},
			);
			$actions->appendChild( $form );
			$form->appendChild( $self->render_hidden_field( "screen", $self->{processor}->{screenid} ) );
			$form->appendChild( $self->render_hidden_field( "dataset", $datasetid ) );
			$form->appendChild( $self->render_hidden_field( "field", $fieldid ) );
			$form->insertBefore( $session->render_input_field(
					name => "new_name",
					type => "text",
					size => "10"
				), $form->firstChild );
		}

		$table->appendChild(
			$session->render_row(
				$session->make_text( $fieldid ),
				$session->html_phrase( "$datasetid\_fieldname\_$fieldid" ),
				$actions
			) );
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

sub render_new_form
{
	my( $self, $dataset ) = @_;

	my $session = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $session->make_doc_fragment;

	my $ds = $session->get_repository->get_dataset( "metafield" );
	
	my $searchexp = EPrints::Search->new(
		session => $session,
		dataset => $ds,
	);
	$searchexp->add_field( $ds->get_field( "mfdatasetid" ), $dataset->confid );
	$searchexp->add_field( $ds->get_field( "mfstatus" ), "inbox" );

	my $list = $searchexp->perform_search;

	my $existing = $session->make_element( "ul" );

	my $uri = URI->new("");

	my $fn = sub {
		my( $session, $ds, $obj ) = @_;

		$uri->query_form(
			screen => $self->{processor}->{screenid},
			name => $obj->get_value( "name" ),
			dataset => $dataset->confid,
			_action_new_field => "1",
		);

		my $li = $session->make_element( "li" );
		my $link = $session->render_link( $uri );
		$existing->appendChild( $li );
		$li->appendChild( $link );
		$link->appendChild( $session->make_text( $obj->get_value( "name" ) ) );

		$uri->query_form(
			screen => $self->{processor}->{screenid},
			name => $obj->get_value( "name" ),
			dataset => $dataset->confid,
			_action_delete_field => "1",
		);

		$link = $session->render_link( $uri );
		$li->appendChild( $session->make_text( " [ " ) );
		$li->appendChild( $link );
		$li->appendChild( $session->make_text( " ]" ) );
		$link->appendChild( $self->html_phrase( "remove" ) );
	};
	$list->map( $fn );

	if( $list->count == 0 )
	{
		my $li = $session->make_element( "li" );
		$existing->appendChild( $li );
		$li->appendChild( $self->html_phrase( "inbox_empty" ) );
	}

	my $form = $session->render_input_form(
		fields => [
			$ds->get_field( "name" ),
		],
		show_names => 1,
		show_help => 1,
		default_action => "new_field",
		buttons => { new_field => $self->phrase( "new" ) },
		hidden_fields => {
			screen => $self->{processor}->{screenid},
			dataset => $dataset->confid,
		},
	);

	my $compound_form = $session->render_input_form(
		fields => [
			$ds->get_field( "name" ),
		],
		show_names => 1,
		show_help => 1,
		default_action => "new_compound_field",
		buttons => { new_compound_field => $self->phrase( "new_compound" ) },
		hidden_fields => {
			screen => $self->{processor}->{screenid},
			dataset => $dataset->confid,
		},
	);

	$html->appendChild( $self->html_phrase( "new_form",
		inbox => $existing,
		form => $form,
		compound_form => $compound_form,
	) );

	return $html;
}

1;
