package EPrints::Plugin::Screen::Workflow::Details;

@ISA = ( 'EPrints::Plugin::Screen::Workflow' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "dataobj_view_tabs",
			position => 100,
		},
	];

	return $self;
}

sub properties_from
{
	my( $self ) = @_;

	$self->SUPER::properties_from;

}

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( $self->{processor}->{dataset}->id."/details" );
}

sub _find_stage
{
	my( $self, $name ) = @_;

	return undef if !$self->{processor}->{can_be_edited};

	return undef if !$self->has_workflow();

	my $workflow = $self->workflow;

	return $workflow->{field_stages}->{$name};
}

sub _render_name_maybe_with_link
{
	my( $self, $field ) = @_;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};

	my $name = $field->get_name;
	my $stage = $self->_find_stage( $name );

	my $r_name = $field->render_name( $self->{session} );
	return $r_name if !defined $stage;

	my $url = "?dataset=".$dataset->id."&dataobj=".$dataobj->id."&screen=".$self->get_edit_screen."&stage=$stage#$name";
	my $link = $self->{session}->render_link( $url );
	$link->appendChild( $r_name );

	return $link;
}

sub render
{
	my( $self ) = @_;

	my $dataset = $self->{processor}->{dataset};
	my $dataobj = $self->{processor}->{dataobj};
	my $session = $self->{session};

	my $unspec_fields = $session->make_doc_fragment;
	my $unspec_first = 1;

	my $page = $session->make_doc_fragment;
	# Show all the fields
	my $table = $session->make_element( "table",
					border=>"0",
					cellpadding=>"3" );
	$page->appendChild( $table );

	foreach my $field ( $dataset->fields )
	{
		next if !$field->get_property( "show_in_html" );
		next if $field->isa( "EPrints::MetaField::Subobject" );

		my $r_name = $self->_render_name_maybe_with_link( $field );

		my $name = $field->get_name();
		if( $dataobj->is_set( $name ) )
		{
			$table->appendChild( $session->render_row(
				$r_name,
				$dataobj->render_value( $name, 1 ) ) );
			next;
		}

		# unspecified value, add it to the list
		if( $unspec_first )
		{
			$unspec_first = 0;
		}
		else
		{
			$unspec_fields->appendChild( 
				$session->make_text( ", " ) );
		}
		$unspec_fields->appendChild( $self->_render_name_maybe_with_link( $field ) );
	}

	my $h3 = $session->make_element( "h3" );
	$page->appendChild( $h3 );
	$h3->appendChild( $session->html_phrase( "lib/dataobj:unspecified" ) );
	$page->appendChild( $unspec_fields );

	return $page;
}




1;
