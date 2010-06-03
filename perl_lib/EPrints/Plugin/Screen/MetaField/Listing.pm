package EPrints::Plugin::Screen::MetaField::Listing;

@ISA = qw( EPrints::Plugin::Screen );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	push @{$self->{actions}}, qw/ edit_field remove_field create_field rename_field cancel /;
		
	$self->{appears} = [
		{ 
			place => "admin_actions_config", 
			position => 2050, 
		},
	];

	return $self;
}

sub edit_screen { "MetaField::Edit" }
sub view_screen { "MetaField::View" }
sub listing_screen { "MetaField::Listing" }
sub can_be_viewed { shift->allow( "config/edit/perl" ) }

sub properties_from
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $datasetid = $repo->param( "dataset" );
	my $fieldname = $repo->param( "field" );

	# this allows us to call other plugins that operate on {dataset}
	my $ds = $repo->dataset( "metafield" );
	$self->{processor}->{dataset} = $ds;

	my $dataset = $repo->dataset( $datasetid );
	if( $self->{processor}->{notes}->{dataset} = $dataset )
	{
		if( defined $fieldname )
		{
			$self->{processor}->{notes}->{field} = $dataset->field( $fieldname );
		}
		$self->{processor}->{search} = $ds->prepare_search(
			filters => [
				{ meta_fields => [qw( mfdatasetid )], value => $datasetid }
			],
			custom_order => "name",
		);
	}

	$self->SUPER::properties_from;
}

*allow_cancel =
*allow_create_field =
*allow_edit_field =
*allow_remove_field = 
*allow_rename_field = 
*allow_delete_field = \&can_be_viewed;

sub action_cancel {}

sub action_create_field
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $dataset = $self->{processor}->{notes}->{dataset};
	return if !defined $dataset;

	my $ds = $repo->dataset( "metafield" );

	my $mf = $ds->create_dataobj( {
		mfdatasetid => $dataset->base_id,
	} );

	$self->{processor}->{dataset} = $ds;
	$self->{processor}->{dataobj} = $mf;
	$self->{processor}->{screenid} = $self->edit_screen;
}	

sub action_edit_field
{
	my( $self ) = @_;

	my $repo = $self->{session};
	my $dataset = $self->{processor}->{notes}->{dataset};
	return if !$dataset;
	my $field = $self->{processor}->{notes}->{field};
	return if !$field;

	my $confirm = $repo->param( "confirm" );

	if( !$confirm )
	{
		my $form = $repo->render_input_form(
			fields => [],
			buttons => { edit_field => $self->phrase( "confirm" ), cancel => $self->phrase( "cancel" ), _order => [qw( edit_field cancel )] },
		);
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "confirm_edit",
				dataset => $repo->make_text( $dataset->id ),
				field => $repo->make_text( $field->name ),
				confirm_button => $form,
			) );
		$form->appendChild( $self->render_hidden_bits );
		$form->appendChild( $self->render_hidden_field( "confirm", 1 ) );
		return;
	}

	my $ds = $repo->dataset( "metafield" );

	my $mf = EPrints::DataObj::MetaField->new_from_field( $repo, $field, $ds )
		or EPrints->abort( "Error creating metafield object" );

	my $sub_fields = $mf->value( "fields" );
	$mf->set_value( "fields", undef );

	$mf = $mf->create_from_data( $repo, $mf->get_data, $ds );
	for(@$sub_fields)
	{
		my $epdata = $_->get_data;
		$epdata->{parent} = $mf->id;
		$mf->create_subdataobj( "fields", $epdata )
			or EPrints->abort( "Error creating metafield sub-field object" );
	}

	if( !$mf->remove_from_repository )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "remove_failed",
				dataset => $repo->make_text( $dataset->id ),
				field => $repo->make_text( $field->name ),
			) );
		return;
	}

	$self->reload_config;

	$self->{processor}->{dataobj} = $mf;
	$self->{processor}->{screenid} = $self->edit_screen;
}

sub action_remove_field
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $dataset = $self->{processor}->{notes}->{dataset};
	return if !defined $dataset;

	my $field = $self->{processor}->{notes}->{field};
	return if !defined $field;

	my $confirm = $repo->param( "confirm" );

	if( !$confirm )
	{
		my $form = $repo->render_input_form(
			fields => [],
			buttons => { remove_field => $self->phrase( "confirm" ), cancel => $self->phrase( "cancel" ), _order => [qw( remove_field cancel )] },
		);
		$self->{processor}->add_message( "warning",
			$self->html_phrase( "confirm_remove",
				dataset => $repo->make_text( $dataset->base_id ),
				field => $repo->make_text( $field->name ),
				confirm_button => $form,
			) );
		$form->appendChild( $self->render_hidden_bits );
		$form->appendChild( $repo->render_hidden_field( "confirm", 1 ) );

		return;
	}

	if( $field->property( "provenance" ) ne "user" )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_user_field",
				dataset => $repo->make_text( $dataset->base_id ),
				field => $repo->make_text( $field->name ),
			) );
		return;
	}

	my $mf = EPrints::DataObj::MetaField->new_from_field( $repo, $field );

	if( $mf->remove_from_repository() )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "removed_field",
				dataset => $repo->make_text( $dataset->base_id ),
				field => $repo->make_text( $field->name ),
			) );

		$self->reload_config;
	}
	else
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "remove_failed",
				dataset => $repo->make_text( $dataset->base_id ),
				field => $repo->make_text( $field->name ),
			) );
	}
}

sub action_rename_field
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $datasetid = $repo->param( "dataset" ) or return;
	my $fieldid = $repo->param( "field" ) or return;
	my $newid = $repo->param( "new_name" ) or return;

	return if $fieldid eq $newid;

	unless( $self->can_change_field( $datasetid, $fieldid ) )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "invalid_field",
				datasetid => $repo->make_text( $datasetid ),
				fieldid => $repo->make_text( $fieldid ),
			) );
		return;
	}

	my $ds = $repo->get_repository->get_dataset( "metafield" );

	my $metafield = $ds->get_object( $repo, $datasetid.".".$fieldid );
	if( !$metafield )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_in_metafield",
				datasetid => $repo->make_text( $datasetid ),
				fieldid => $repo->make_text( $fieldid )
			) );
		return;
	}

	if( $metafield->get_value( "provenance" ) ne "user" )
	{
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_user_field",
				datasetid => $repo->make_text( $datasetid ),
				fieldid => $repo->make_text( $fieldid )
			) );
		return;
	}

	my $dataset = $repo->get_repository->get_dataset( $datasetid );

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
	$repo->get_database->rename_field( $dataset, $new_field, $fieldid );

	# register the new field name
	$dataset->register_field( $new_field );

	my $ok = EPrints::DataObj::MetaField::save_all( $repo );

	if( $ok )
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "renamed_field",
				datasetid => $repo->make_text( $datasetid ),
				fieldid => $repo->make_text( $fieldid ),
				newid => $repo->make_text( $newid ),
			) );

		$self->reload_config;
	}
	else
	{
		$self->{processor}->add_message( "message",
			$self->html_phrase( "rename_failed",
				datasetid => $repo->make_text( $datasetid ),
				fieldid => $repo->make_text( $fieldid ),
				newid => $repo->make_text( $newid ),
			) );
	}
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{notes}->{dataset};
	return $self->SUPER::redirect_to_me_url if !defined $dataset;

	return $self->SUPER::redirect_to_me_url."&dataset=".$dataset->base_id;
}

sub reload_config
{
	my( $self ) = @_;

	my $plugin = $self->{session}->plugin( "Screen::Admin::Reload",
		processor => $self->{processor}
	);
	if( defined $plugin )
	{
		local $self->{processor}->{screenid};
		$plugin->action_reload_config;
	}
}

sub render_title
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;

	my $dataset = $self->{processor}->{notes}->{dataset};

	if( $dataset )
	{
		my $url = URI->new( $self->{session}->current_url );
		$url->query_form(
			screen => $self->{processor}->{screenid}
		);
		my $frag = $xml->create_document_fragment;
		my $link = $xml->create_element( "a", href => $url );
		$frag->appendChild( $link );
		$link->appendChild( $self->html_phrase( "title" ) );
		$frag->appendChild( $xml->create_text_node( " - " ) );
		$frag->appendChild( $dataset->render_name( $self->{session} ) );
		return $frag;
	}
	else
	{
		return $self->html_phrase( "title" );
	}
}

sub render
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $dataset = $self->{processor}->{notes}->{dataset};

	my( $html , $table , $p , $span );
	
	$html = $repo->make_doc_fragment;

	my $fields = $repo->get_repository->get_conf( "fields" );

	$html->appendChild( $self->html_phrase( "help" ) );

	if( defined $dataset )
	{
		$html->appendChild( $self->render_action_buttons( $dataset ) );

		$html->appendChild( $self->render_fields( $dataset ) );

		$html->appendChild( $self->render_dataset( $dataset ) );
	}
	else
	{
		$html->appendChild( $self->html_phrase( "datasets" ) );

		$table = $repo->make_element( "table", border=>"0" );
		$html->appendChild( $table );

		foreach my $datasetid (sort $repo->get_dataset_ids)
		{
			my $dataset = $repo->dataset( $datasetid );
			next if $dataset->is_virtual;
			my $u = URI->new( $repo->current_url );
			$u->query_form(
				screen => $self->{processor}->{screenid},
				dataset => $datasetid
			);
			my $link = $repo->render_link( $u );
			$table->appendChild(
				$repo->render_row(
					$dataset->render_name( $repo ),
					$repo->html_phrase( "datasethelp_$datasetid" ),
					$link,
				) );
			$link->appendChild( $self->html_phrase( "edit_dataset",
				dataset => $repo->make_text( $datasetid )
				) );
		}
	}

	return $html;
}

sub render_action_buttons
{
	my( $self, $dataset ) = @_;

	my $repo = $self->{session};

	my $div = $repo->xml->create_element( "div", class => "ep_act_buttons" );

	my $form = $repo->render_form();
	$div->appendChild( $form );
	$form->appendChild( $self->render_hidden_bits );
	$form->appendChild( $repo->render_action_buttons(
		_order=>[qw( create_field )],
		_class=>"ep_form_button_bar",
		create_field => $self->phrase( "create_field" ),
	) );

	return $div;
}

sub render_fields
{
	my( $self, $dataset ) = @_;

	my $repo = $self->{session};

	my $frag = $repo->make_doc_fragment;

	my $results = $self->{processor}->{search}->perform_search;

	return $frag if $results->count == 0;

	my $h2 = $repo->make_element( "h2" );
	$frag->appendChild( $h2 );
	$h2->appendChild( $self->html_phrase( "buffer" ) );

	my $div = $repo->make_element( "div", class => "ep_block" );
	$frag->appendChild( $div );

	my $table = $repo->make_element( "table", border=>"0" );
	$div->appendChild( $table );

	$results->map(sub {
		my( undef, undef, $mf ) = @_;

		local $self->{processor}->{dataobj} = $mf;

		$table->appendChild( $repo->render_row(
			$repo->make_text( $mf->value( "name" ) ),
			$self->render_action_list_icons( "dataobj_actions", {
				dataset => $self->{processor}->{dataset}->id,
				dataobj => $mf->id,
			} ),
		) );
	});

	return $frag;
}

sub render_dataset
{
	my( $self, $dataset ) = @_;

	my $repo = $self->{session};

	my( $html , $table , $p , $span );
	
	$html = $repo->make_doc_fragment;

	my $h2 = $repo->make_element( "h2" );
	$html->appendChild( $h2 );
	$h2->appendChild( $self->html_phrase( "repository" ) );

	$table = $repo->make_element( "table", border=>"0" );
	$html->appendChild( $table );

	foreach my $rfield (sort { $a->{name} cmp $b->{name} } $dataset->fields)
	{
		next if defined $rfield->property( "sub_name" );

		my @fields = ($rfield);
		if( $rfield->isa( "EPrints::MetaField::Compound" ) )
		{
			push @fields, sort { $a->{sub_name} cmp $b->{sub_name} } @{$rfield->property( "fields_cache" )};
		}

		foreach my $field (@fields)
		{
			local $self->{processor}->{notes}->{field} = $field;

			my $actions = $repo->make_doc_fragment;

			if( $field ne $rfield )
			{
			}
			elsif( $field->property( "provenance" ) eq "core" )
			{
				$actions->appendChild( $self->html_phrase( "core_field" ) );
			}
			elsif( $field->property( "provenance" ) eq "config" )
			{
				$actions->appendChild( $self->html_phrase( "config_field" ) );
			}
			else
			{
				my $form = $repo->render_input_form(
					fields => [],
					show_names => 0,
					show_help => 0,
					buttons => {
							edit_field => $self->phrase( "edit" ),
							remove_field => $self->phrase( "remove" ),
#							rename_field => $self->phrase( "rename" ),
							_order => [qw( edit_field remove_field )],
						},
				);
				$form->appendChild( $self->render_hidden_bits );
#				$form->insertBefore( $repo->render_input_field(
#						name => "new_name",
#						type => "text",
#						size => "10"
#					), $form->firstChild );
				$actions->appendChild( $form );
			}

			if( $field ne $rfield )
			{

				my $name = $repo->make_doc_fragment;
				$name->appendChild( $repo->make_text( chr(0x21b3) . " " ) );
				$name->appendChild( $field->render_name( $repo ) );
				$table->appendChild(
					$repo->render_row(
						$repo->make_text( $field->property( "sub_name" ) ),
						$name,
						$actions,
					) );
			}
			else
			{
				$table->appendChild(
					$repo->render_row(
						$repo->make_text( $field->name ),
						$field->render_name( $repo ),
						$actions
					) );
			}
		}
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

sub render_hidden_bits
{
	my( $self ) = @_;

	my $xml = $self->{session}->xml;
	my $xhtml = $self->{session}->xhtml;

	my $frag = $xml->create_document_fragment;

	$frag->appendChild( $self->SUPER::render_hidden_bits );

	if( defined $self->{processor}->{notes}->{dataset} )
	{
		$frag->appendChild( $xhtml->hidden_field( "dataset", $self->{processor}->{notes}->{dataset}->base_id ) );
	}
	if( defined $self->{processor}->{notes}->{field} )
	{
		$frag->appendChild( $xhtml->hidden_field( "field", $self->{processor}->{notes}->{field}->name ) );
	}

	return $frag;
}

1;
