######################################################################
#
# EPrints::MetaField::Subobject;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Subobject> - Sub Object an object.

=head1 DESCRIPTION

This is an abstract field which represents an item, or list of items,
in another dataset, but which are a sub part of the object to which
this field belongs, and have no indepentent status.

For example: Documents are part of EPrints.

=over 4

=cut

package EPrints::MetaField::Subobject;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub get_sql_type
{
	my( $self, $session ) = @_;

	return undef;
}


# This type of field is virtual.
sub is_virtual
{
	my( $self ) = @_;

	return 1;
}

######################################################################

sub get_property_defaults
{
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED; 
	$defaults{dataset_fieldname} = "datasetid";
	$defaults{dataobj_fieldname} = "objectid";
	$defaults{show_in_fieldlist} = 0;
	$defaults{match} = "IN";

	return %defaults;
}

sub render_xml_schema
{
	my( $self, $session ) = @_;

	my $datasetid = $self->get_property( "datasetid" );

	my $element = $session->make_element( "xs:element", name => $self->get_name );

	if (!$self->property("required"))
	{
		$element->setAttribute( minOccurs => 0 );
	}

	if( $self->get_property( "multiple" ) )
	{
		my $complexType = $session->make_element( "xs:complexType" );
		$element->appendChild( $complexType );
		my $sequence = $session->make_element( "xs:sequence" );
		$complexType->appendChild( $sequence );
		my $item = $session->make_element( "xs:element", name => $datasetid, maxOccurs => "unbounded", type => $self->get_xml_schema_type() );
		$sequence->appendChild( $item );
	}
	else
	{
		$element->setAttribute( type => $self->get_xml_schema_type() );
	}

	return $element;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return "dataset_".$self->get_property( "datasetid" );
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	return $session->make_doc_fragment;
}

=item $field->set_value( $dataobj, $value )

B<Cache> the $value in the data object. To actually update the value in the database you must commit the $value objects.

=cut

sub set_value
{
	my( $self, $dataobj, $value ) = @_;

	# don't populate changed nor perform an _equal for object caching
	$dataobj->{data}->{$self->get_name} = $value;
}

sub get_value
{
	my( $self, $parent ) = @_;

	# sub-object caching
	my $value = $self->SUPER::get_value( $parent );
	return $value if defined $value;

	# parent doesn't have an id defined
	return $self->property( "multiple" ) ? [] : undef
		if !EPrints::Utils::is_set( $parent->id );

	my $ds = $parent->get_session->dataset( $self->get_property( "datasetid" ) );

	my $searchexp = $ds->prepare_search();

	if( $ds->base_id eq "document" )
	{
		$searchexp->add_field(
			$ds->field( "eprintid" ),
			$parent->id
		);
	}
	elsif( $ds->base_id eq "saved_search" )
	{
		$searchexp->add_field(
			$ds->field( "userid" ),
			$parent->id
		);
	}
	else
	{
		my $fieldname = $self->get_property( "dataset_fieldname" );
		if( EPrints::Utils::is_set( $fieldname ) )
		{
			if( !$ds->has_field( $fieldname ) )
			{
				EPrints->abort( "dataset_fieldname property on ".$self->{dataset}->id.".".$self->{name}." is not a valid field on ".$ds->id );
			}
			$searchexp->add_field(
				$ds->field( $fieldname ),
				$parent->get_dataset->base_id
			);
		}
		$fieldname = $self->get_property( "dataobj_fieldname" );
		if( !$ds->has_field( $fieldname ) )
		{
			EPrints->abort( "dataobj_fieldname property on ".$self->{dataset}->id.".".$self->{name}." is not a valid field on ".$ds->id );
		}
		$searchexp->add_field(
			$ds->field( $fieldname ),
			$parent->id
		);
	}

	my $results = $searchexp->perform_search;
	my @records = $results->slice;

	if( scalar @records && $records[0]->isa( "EPrints::DataObj::SubObject" ) )
	{
		foreach my $record (@records)
		{
			$record->set_parent( $parent );
		}
	}

	if( $self->get_property( "multiple" ) )
	{
		return \@records;
	}
	else
	{
		return $records[0];
	}
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	return $value->render_citation_link( "default" );
}

sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	return EPrints::Search::Condition::False->new()
		if $match ne "IN";

	my( $codes ) = EPrints::MetaField::Text::get_index_codes_basic(
		$self,
		$session,
		$search_value
	);

	return EPrints::Search::Condition::Pass->new()
		if !@$codes;

	if( $search_value =~ s/\*$// )
	{
		return EPrints::Search::Condition::IndexStart->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
	else
	{
		return EPrints::Search::Condition::Index->new( 
				$dataset,
				$self, 
				$codes->[0] );
	}
}

sub get_index_codes_basic
{
	my( $self, $session, $doc ) = @_;

	# only know how to get index codes out of documents
	return( [], [], [] ) if !$doc->isa( "EPrints::DataObj::Document" );

	# we only supply index codes for proper documents
	return( [], [], [] ) if $doc->has_relation( undef, "isVolatileVersionOf" );

	my $main_file = $doc->get_stored_file( $doc->get_main );
	return( [], [], [] ) unless defined $main_file;

	my $indexcodes_doc = $doc->search_related( "isIndexCodesVersionOf" )->item( 0 );
	my $indexcodes_file;
	if( defined $indexcodes_doc )
	{
		$indexcodes_file = $indexcodes_doc->get_stored_file( "indexcodes.txt" );
	}

	# (re)generate indexcodes if it doesn't exist or is out of date
	if( !defined( $indexcodes_doc ) || !defined( $indexcodes_file ) ||
		$main_file->get_datestamp() gt $indexcodes_file->get_datestamp() )
	{
		$indexcodes_doc = $doc->make_indexcodes();
		if( defined( $indexcodes_doc ) )
		{
			$indexcodes_file = $indexcodes_doc->get_stored_file( "indexcodes.txt" );
		}
	}

	return( [], [], [] ) unless defined $indexcodes_doc;

	my $data = "";
	$indexcodes_file->get_file(sub {
		$data .= $_[0];
	});
	$data = Encode::decode_utf8( $data );
	my @codes = split /\r?\n/, $data;

	return( \@codes, [], [] );
}

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $dataset = $self->dataset;
	my $name = $self->name;

	$handler->start_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
		Attributes => {},
	});

	for($self->property( "multiple" ) ? @$value : $value)
	{
		next if(
			$opts{hide_volatile} &&
			$_->isa( "EPrints::DataObj::Document" ) &&
			$_->has_relation( undef, "isVolatileVersionOf" )
		);
		$_->to_sax( %opts );
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
}

sub empty_value
{
	return {};
}

sub start_element
{
	my( $self, $data, $epdata, $state ) = @_;

	++$state->{depth};

	if( defined(my $handler = $state->{handler}) )
	{
		$handler->start_element( $data, $state->{epdata}, $state->{child} );
	}
	elsif( $state->{depth} == 1 && $self->property( "multiple" ) )
	{
		$epdata->{$self->name} = [];
	}
	elsif( $state->{depth} == 2 )
	{
		my $ds = $self->{repository}->dataset( $self->property( "datasetid" ) );
		my $class = $ds->get_object_class;

		if( $data->{LocalName} ne $ds->base_id )
		{
			if( $state->{Handler} )
			{
				$state->{Handler}->message( "warning", $self->{repository}->xml->create_text_node( "Invalid XML element: $data->{LocalName}" ) );
			}
			undef $state->{handler};
			return;
		}

		$state->{child} = {%$state,
			dataset => $ds,
			depth => 0,
		};
		$state->{epdata} = {};
		$state->{handler} = $class;

		$class->start_element( $data, $state->{epdata}, $state->{child} );
	}
}

sub end_element
{
	my( $self, $data, $epdata, $state ) = @_;

	if( defined(my $handler = $state->{handler}) )
	{
		$handler->end_element( $data, $state->{epdata}, $state->{child} );
	}

	if( $state->{depth} == 2 ) # single object is still: <foo><document>
	{
		if( $self->property( "multiple" ) )
		{
			push @{$epdata->{$self->name}}, delete $state->{epdata};
		}
		else
		{
			$epdata->{$self->name} = delete $state->{epdata};
		}
		delete $state->{child};
		delete $state->{handler};
	}

	--$state->{depth};
}

sub characters
{
	my( $self, $data, $epdata, $state ) = @_;

	if( defined(my $handler = $state->{handler}) )
	{
		$handler->characters( $data, $state->{epdata}, $state->{child} );
	}
}

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

