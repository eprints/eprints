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

sub index_fulltext 
{
	my( $self, $dataobj ) = @_;

	if( !defined $dataobj )
	{
		Carp::carp "Expected dataobj argument";
		return 0;
	}

	my $dataset = $dataobj->get_dataset;

	my $field = EPrints::MetaField->new( 
				dataset => $dataset, 
				name => "_fulltext_",
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

		my $value = $field->get_value( $dataobj );
		next unless EPrints::Utils::is_set( $value );	

		EPrints::Index::add( $session, $dataset, $dataobj->get_id, $field->get_name, $value );
	}

	return 1;
}	

1;
