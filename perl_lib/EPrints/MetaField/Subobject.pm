######################################################################
#
# EPrints::MetaField::Subobject;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

	return %defaults;
}

sub render_xml_schema
{
	my( $self, $session ) = @_;

	my $datasetid = $self->get_property( "datasetid" );

	my $element = $session->make_element( "xs:element", name => $self->get_name );

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
		my $fieldname;
		$fieldname = $self->get_property( "dataset_fieldname" );
		if( EPrints::Utils::is_set( $fieldname ) )
		{
			$searchexp->add_field(
				$ds->field( $fieldname ),
				$parent->get_dataset->base_id
			);
		}
		$fieldname = $self->get_property( "dataobj_fieldname" );
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

	return $value->render_citation( "default" );
}

sub get_index_codes_basic
{
	my( $self, $session, $doc ) = @_;

	# only know how to get index codes out of documents
	return( [], [], [] ) if !$doc->isa( "EPrints::DataObj::Document" );

	# we only supply index codes for proper documents
	return( [], [], [] ) if $doc->has_related_objects(
		EPrints::Utils::make_relation( "isVolatileVersionOf" )
	);

	my $main_file = $doc->get_stored_file( $doc->get_main );
	return( [], [], [] ) unless defined $main_file;

	my( $indexcodes_doc ) = @{($doc->get_related_objects(
			EPrints::Utils::make_relation( "hasIndexCodesVersion" )
		))};
	my $indexcodes_file;
	if( defined $indexcodes_doc )
	{
		$indexcodes_file = $indexcodes_doc->get_stored_file( "indexcodes.txt" );
	}

	# (re)generate indexcodes if it doesn't exist or is out of date
	if( !defined( $indexcodes_doc ) ||
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
	my @codes = split /\n/, $data;

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
			$_->has_related_objects( EPrints::Utils::make_relation( "isVolatileVersionOf" ) )
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
