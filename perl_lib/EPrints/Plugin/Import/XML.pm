package EPrints::Plugin::Import::XML;

use strict;

use EPrints::Plugin::Import::DefaultXML;

our @ISA = qw/ EPrints::Plugin::Import::DefaultXML /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "XML";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/*', 'dataobj/*' ];

	return $self;
}

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return $dataset->confid."s";
}

sub unknown_start_element
{
	my( $self, $found, $expected ) = @_;

	if( $found eq "eprintsdata" ) 
	{
		$self->warning( "You appear to be attempting to import an EPrints 2 XML file!\nThis importer only handles v3 files. Use the migration toolkit to convert!\n" );
	}
	$self->SUPER::unknown_start_element( @_[1..$#_] );
}

sub xml_to_epdata
{
	my( $plugin, $dataset, $xml ) = @_;

	my @fields = $dataset->get_fields;
	my @fieldnames = ();
	foreach( @fields ) { push @fieldnames, $_->get_name; }

	my %toprocess = $plugin->get_known_nodes( $xml, @fieldnames );

	my $epdata = {};
	foreach my $fn ( keys %toprocess )
	{
		my $field = $dataset->get_field( $fn );
		$epdata->{$fn} = $plugin->xml_field_to_epdatafield( $dataset, $field, $toprocess{$fn} );
	}
	return $epdata;
}

sub xml_field_to_epdatafield
{
	my( $plugin,$dataset,$field,$xml ) = @_;

	unless( $field->get_property( "multiple" ) )
	{
		return $plugin->xml_field_to_data_single( $dataset,$field,$xml );
	}

	my $epdatafield = [];
	my @list = $xml->getChildNodes;
	foreach my $el ( @list )
	{
		next unless EPrints::XML::is_dom( $el, "Element" );
		my $type = $el->nodeName;
		if( $field->is_type( "subobject" ) )
		{
			my $expect = $field->get_property( "datasetid" );
			if( $type ne $expect )
			{
				$plugin->warning( $plugin->phrase( "unexpected_type", 
					type => $type, 
					expected => $expect, 
					fieldname => $field->get_name ) );
				next;
			}
			my $sub_dataset = $plugin->{session}->get_repository->get_dataset( $expect );
			push @{$epdatafield}, $plugin->xml_to_epdata( $sub_dataset,$el );
			next;
		}

		if( $field->is_virtual && !$field->is_type( "compound","multilang") )
		{
			$plugin->warning( $plugin->phrase( "unknown_virtual", type => $type, fieldname => $field->get_name ) );
			next;
		}
	

		if( $type ne "item" )
		{
			$plugin->warning( $plugin->phrase( "expected_item", type => $type, fieldname => $field->get_name ) );
			next;
		}
		push @{$epdatafield}, $plugin->xml_field_to_data_single( $dataset,$field,$el );
	}

	return $epdatafield;
}

sub xml_field_to_data_single
{
	my( $plugin,$dataset,$field,$xml ) = @_;

#	unless( $field->get_property( "multiple" ) )
#	{
#		return $plugin->xml_field_to_data_single( $dataset,$field,$xml );
#	}
	return $plugin->xml_field_to_data_basic( $dataset, $field, $xml );
}

sub xml_field_to_data_basic
{
	my( $plugin,$dataset,$field,$xml ) = @_;

	if( $field->is_type( "compound","multilang") )
	{
		my $data = {};
		my @list = $xml->getChildNodes;
		my %a_to_f = $field->get_alias_to_fieldname;
		foreach my $el ( @list )
		{
			next unless EPrints::XML::is_dom( $el, "Element" );
			my $nodename = $el->nodeName();
			my $name = $a_to_f{$nodename};
			if( !defined $name )
			{
				$plugin->warning( "Unknown element found inside compound field: $nodename. (skipping)" );
				next;
			}
			my $f = $dataset->get_field( $name );
			$data->{$nodename} = $plugin->xml_field_to_data_basic( $dataset, $f, $el );
		}
		return $data;
	}

	unless( $field->is_type( "name" ) )
	{
		return $plugin->xml_to_text( $xml );
	}

	my %toprocess = $plugin->get_known_nodes( $xml, qw/ given family lineage honourific / );

	my $epdatafield = {};
	foreach my $part ( keys %toprocess )
	{
		$epdatafield->{$part} = $plugin->xml_to_text( $toprocess{$part} );
	}
	return $epdatafield;
}

sub get_known_nodes
{
	my( $plugin, $xml, @whitelist ) = @_;

	my @list = $xml->getChildNodes;
	my %map = ();
	foreach my $el ( @list )
	{
		next unless EPrints::XML::is_dom( $el, "Element" );
		if( defined $map{$el->nodeName()} )
		{
			$plugin->warning( $plugin->phrase( "dup_element", name => $el->nodeName ) );
			next;
		}
		$map{$el->nodeName()} = $el;
	}

	my %toreturn = ();
	foreach my $oknode ( @whitelist ) 
	{
		next unless defined $map{$oknode};
		$toreturn{$oknode} = $map{$oknode};
		delete $map{$oknode};
	}

	foreach my $name ( keys %map )
	{
		$plugin->warning( $plugin->phrase( "unexpected_element", name => $name ) );
		$plugin->warning( $plugin->phrase( "expected", elements => "<".join("> <", @whitelist).">" ) );
	}
	return %toreturn;
}



	


	

1;
