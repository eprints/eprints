package EPrints::Plugin::Export::ContextObject::Journal;

use EPrints::Plugin::Export::ContextObject;

@ISA = ( "EPrints::Plugin::Export::ContextObject" );

use strict;

# map eprint type to genre

our %MAPPING = qw(
	title	atitle
	volume	volume
	number	issue
	series	series
	publication	title
	pagerange	pages
	date	date
	issn	issn
	isbn	isbn
);
our %TYPE_MAPPING = qw(
	article	article
	conference_item	conference
	misc	unknown
);

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "OpenURL Journal";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";

	return $self;
}

sub convert_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	my $data = $plugin->SUPER::convert_dataobj( $dataobj, %opts );

	my $dataset = $dataobj->get_dataset;

	if( $dataset->has_field( "type" ) and $dataobj->is_set( "type" ) )
	{
		my $genre = $TYPE_MAPPING{$dataobj->get_value( "type" )};

		if( defined $genre )
		{
			push @$data, [ genre => $genre ];
		}
	}

	return $data;
}

sub xml_dataobj
{
	my( $plugin, $dataobj, %opts ) = @_;

	return $plugin->xml_entity_dataobj( $dataobj, %opts,
		mapping => \%MAPPING,
		prefix => "jnl",
		namespace => "info:ofi/fmt:xml:xsd:journal",
		schemaLocation => "info:ofi/fmt:xml:xsd:journal http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:journal",
	);
}

sub kev_dataobj
{
	my( $plugin, $dataobj, $ctx ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj, mapping => \%MAPPING );

	# Can only include the first author in KEV
	my $first_author;
	for(my $i = 0; $i < @$data; ++$i)
	{
		if( $data->[$i]->[0] eq "author" )
		{
			my $e = splice @$data, $i, 1;
			--$i;
			$first_author ||= $e->[1];
		}
	}
	$first_author ||= {};
	# Sorry, this is a very compact way of expanding out the sub-arrays
	@$data = (%$first_author, map { @$_ } @$data);

	$ctx->journal( @$data );
}

1;
