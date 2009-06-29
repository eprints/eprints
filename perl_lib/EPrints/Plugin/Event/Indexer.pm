package EPrints::Plugin::Event::Indexer;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub run_index
{
	my( $self, $event, $uri, @fieldnames ) = @_;

	my $dataobj = EPrints::DataSet->get_object_from_uri( $self->{session}, $uri );
	if( !defined $dataobj )
	{
		$self->plain_message( "warning", "Failed to retrieve object identified by '$uri'" );
		return 1;
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

sub run_index_all
{
	my( $self, $event, $uri ) = @_;

	my $dataobj = EPrints::DataSet->get_object_from_uri( $self->{session}, $uri );
	if( !defined $dataobj )
	{
		$self->plain_message( "warning", "Failed to retrieve object identified by '$uri'" );
		return 1;
	}

	my $dataset = $dataobj->get_dataset;

	return $self->_index_fields( $dataobj, [$dataset->get_fields] );
}

sub run_index_fulltext 
{
	my( $self, $event, $uri ) = @_;

	my $dataobj = EPrints::DataSet->get_object_from_uri( $self->{session}, $uri );
	if( !defined $dataobj )
	{
		$self->plain_message( "warning", "Failed to retrieve object identified by '$uri'" );
		return 1;
	}

	my $dataset = $dataobj->get_dataset;

	my $field = EPrints::MetaField->new( 
				dataset => $dataset, 
				name => "_FULLTEXT_",
				multiple => 1,
				type => "fulltext" );

	return $self->_index_fields( $dataobj, [$field] );
}

sub _index_fields
{
	my( $self, $dataobj, $fields ) = @_;

	my $session = $self->{session};
	my $dataset = $dataobj->get_dataset;

	foreach my $field (@$fields)
	{
		EPrints::Index::remove( $session, $dataset, $dataobj->get_id, $field->get_name );
		next unless( $field->get_property( "text_index" ) );

$self->plain_message( "message", "indexing ".$dataset->confid.".".$dataobj->get_id.".".$field->get_name );
		my $value = $field->get_value( $dataobj );
		next unless EPrints::Utils::is_set( $value );	

		EPrints::Index::add( $session, $dataset, $dataobj->get_id, $field->get_name, $value );
	}

	return 1;
}	

1;
