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

	my $epdata = $dataset->get_object_class->xml_to_epdata(
		$plugin->{handle},
		$xml,
		Handler => $plugin->{Handler} );

	return $epdata;
}

1;
