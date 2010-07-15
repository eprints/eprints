package EPrints::Plugin::Event::Indexer;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub index
{
	my( $self, $dataobj, @fieldnames ) = @_;

	if( !defined $dataobj )
	{
		Carp::carp "Expected dataobj argument";
		return 0;
	}

	my $dataset = $dataobj->get_dataset;

	my @fields;
	for(@fieldnames)
	{
		next unless $dataset->has_field( $_ );
		push @fields, $dataset->get_field( $_ );
	}

	return $self->_index_fields( $dataobj, \@fields );
}

sub index_all
{
	my( $self, $dataobj ) = @_;

	if( !defined $dataobj )
	{
		Carp::carp "Expected dataobj argument";
		return 0;
	}

	my $dataset = $dataobj->get_dataset;

	return $self->_index_fields( $dataobj, [$dataset->get_fields] );
}

sub removed
{
	my( $self, $datasetid, $id ) = @_;

	my $dataset = $self->{session}->dataset( $datasetid );
	return if !defined $dataset;

	my $rc = $self->{session}->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_REMOVED,
		dataset => $dataset,
		id => $id,
	);
	return 1 if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	foreach my $field ($dataset->fields)
	{
		EPrints::Index::remove( $self->{session}, $dataset, $id, $field->name );
	}
}

sub _index_fields
{
	my( $self, $dataobj, $fields ) = @_;

	my $session = $self->{session};
	my $dataset = $dataobj->get_dataset;

	my $rc = $session->run_trigger( EPrints::Const::EP_TRIGGER_INDEX_FIELDS,
		dataobj => $dataobj,
		fields => $fields,
	);
	return 1 if defined $rc && $rc eq EPrints::Const::EP_TRIGGER_DONE;

	foreach my $field (@$fields)
	{
		EPrints::Index::remove( $session, $dataset, $dataobj->get_id, $field->get_name );
		next unless( $field->get_property( "text_index" ) );

		my $value = $field->get_value( $dataobj );
		next unless EPrints::Utils::is_set( $value );	

		EPrints::Index::add( $session, $dataset, $dataobj->get_id, $field->get_name, $value );
	}

	return 1;
}	

1;
