package EPrints::Plugin::Screen::EPrint::Details;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 100,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;
		
	return $self->allow( "eprint/details" );
}

sub _render_name_maybe_with_link
{
	my( $self, $eprint, $field ) = @_;

	my $r_name = $field->render_name( $eprint->{session} );

	return $r_name unless $self->allow( "eprint/edit" ) & 4;

	my $name = $field->get_name;

	my $workflow = $self->workflow;
	my $stage = $workflow->{field_stages}->{$name};
	return $r_name if( !defined $stage );

	my $url = "?eprintid=".$eprint->get_id."&screen=EPrint::Edit&stage=$stage#$name";
	my $link = $eprint->{session}->render_link( $url );
	$link->appendChild( $r_name );
	return $link;
}


sub render
{
	my( $self ) = @_;

	my $eprint = $self->{processor}->{eprint};

	my $unspec_fields = $eprint->{session}->make_doc_fragment;
	my $unspec_first = 1;

	# Show all the fields
	my $table = $eprint->{session}->make_element( "table",
					border=>"0",
					cellpadding=>"3" );

	my @fields = $eprint->get_dataset->get_fields;
	foreach my $field ( @fields )
	{
		next unless( $field->get_property( "show_in_html" ) );
		next if( $field->is_type( "subobject" ) );

		my $r_name = $self->_render_name_maybe_with_link( $eprint, $field );

		my $name = $field->get_name();
		if( $eprint->is_set( $name ) )
		{
			$table->appendChild( $eprint->{session}->render_row(
				$r_name,
				$eprint->render_value( $field->get_name(), 1 ) ) );
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
				$eprint->{session}->make_text( ", " ) );
		}
		$unspec_fields->appendChild( $self->_render_name_maybe_with_link( $eprint, $field ) );
	}

	$table->appendChild( $eprint->{session}->render_row(
			$eprint->{session}->html_phrase( "lib/dataobj:unspecified" ),
			$unspec_fields ) );

	return $table;
}




1;
