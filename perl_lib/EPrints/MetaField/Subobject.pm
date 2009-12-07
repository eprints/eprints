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

	my $ds = $parent->get_session->get_repository->get_dataset( $self->get_property( "datasetid" ) );

	my( $keyfield ) = $ds->get_fields;
	my $keyname = $keyfield->get_name;

	my $searchexp = EPrints::Search->new(
		session => $parent->get_session,
		dataset => $ds,
		custom_order => "-$keyname",
	);

	if( $ds->confid eq "document" )
	{
		$searchexp->add_field(
			$ds->get_field( "eprintid" ),
			$parent->get_id
		);
	}
	elsif( $ds->confid eq "saved_search" )
	{
		$searchexp->add_field(
			$ds->get_field( "userid" ),
			$parent->get_id
		);
	}
	else
	{
		$searchexp->add_field(
			$ds->get_field( "datasetid" ),
			$parent->get_dataset->confid
		);
		$searchexp->add_field(
			$ds->get_field( "objectid" ),
			$parent->get_id
		);
	}

	my $list = $searchexp->perform_search;
	my @records = $list->get_records;
	$searchexp->dispose;

	foreach my $record (@records)
	{
		$record->set_parent( $parent );
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

sub to_xml
{
	my( $self, $session, $value, $dataset, %opts ) = @_;

	# don't show empty fields
	if( !$opts{show_empty} && !EPrints::Utils::is_set( $value ) )
	{
		return $session->make_doc_fragment;
	}

	if( $self->get_property( "multiple" ) )
	{
		my $tag = $session->make_element( $self->get_name() );
		foreach my $dataobj ( @{$value||[]} )
		{
			$tag->appendChild( $dataobj->to_xml( %opts ) );
		}
		return $tag;
	}
	elsif( defined $value )
	{
		return $value->to_xml( %opts );
	}
	else
	{
		return $session->make_doc_fragment;
	}
}

sub xml_to_epdata
{
	my( $self, $session, $xml, %opts ) = @_;

	my $value = undef;

	if( $self->get_property( "multiple" ) )
	{
		$value = [];
		foreach my $node ($xml->childNodes)
		{
			next unless EPrints::XML::is_dom( $node, "Element" );
			my $epdata = $self->xml_to_epdata_basic( $session, $node, %opts );
			if( defined $epdata )
			{
				push @$value, $epdata;
			}
		}
	}
	else
	{
		$value = $self->xml_to_epdata_basic( $session, $xml, %opts );
	}

	return $value;
}

sub xml_to_epdata_basic
{
	my( $self, $session, $xml, %opts ) = @_;

	my $datasetid = $self->get_property( "datasetid" );

	my $ds = $session->get_repository->get_dataset( $datasetid );
	my $class = $ds->get_object_class;

	my $nodeName = $xml->nodeName;
	if( $nodeName ne $datasetid )
	{
		if( defined $opts{Handler} )
		{
			$opts{Handler}->message( "warning", $session->html_phrase( "Plugin/Import/XML:unexpected_element", name => $session->make_text( $nodeName ) ) );
			$opts{Handler}->message( "warning", $session->html_phrase( "Plugin/Import/XML:expected", elements => $session->make_text( "<$datasetid>" ) ) );
		}
		return undef;
	}

	return $class->xml_to_epdata( $session, $xml, %opts );
}

######################################################################
1;
