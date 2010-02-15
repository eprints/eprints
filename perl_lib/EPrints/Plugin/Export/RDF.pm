package EPrints::Plugin::Export::RDF;

# This virtual super-class supports RDF serialisations

use EPrints::Plugin::Export::TextFile;

our @ISA = qw( EPrints::Plugin::Export::TextFile );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{handles_rdf} = 1;

	return $self;
}

sub get_namespaces
{
	my( $plugin ) = @_;

	return $plugin->{session}->get_repository->get_conf( "rdf","xmlns");
}

sub cache_dataobj_triples
{
	my( $plugin, $dataobj, $cache, $uri ) = @_;

	TRIP: foreach my $trip ( @{ $dataobj->triples } )
	{
		next TRIP if( $uri && $trip->{resource} ne $uri );
		my $hashkey = ($trip->{object}||"").'^^'.($trip->{type}||"").'@'.($trip->{lang}||"");
		$cache->{$trip->{subject}}->{$trip->{predicate}}->{$hashkey} =
			[ $trip->{object}||"", $trip->{type}, $trip->{lang} ];
	}
}

sub cache_general_triples
{
	my( $plugin, $cache ) = @_;

	my $triples = {};
	$plugin->{session}->run_trigger( "rdf_triples_general",  triples=>$triples );

	foreach my $resource ( keys %{$triples} )
	{
		foreach my $spo ( @{$triples->{$resource}} )
		{
			my $trip = {
				resource=>$resource,
				subject=>$spo->[0],
				predicate=>$spo->[1],
				object=>$spo->[2],
				type=>$spo->[3],
				lang=>$spo->[4] };
			my $hashkey = ($trip->{object}||"").'^^'.($trip->{type}||"").'@'.($trip->{lang}||"");
			$cache->{$trip->{subject}}->{$trip->{predicate}}->{$hashkey} =
				[ $trip->{object}||"", $trip->{type}, $trip->{lang} ];
		}
	}
}

sub dataobj_export_url
{
	my( $plugin, $dataobj, $staff ) = @_;

	if( $dataobj->isa( "EPrints::DataObj::SubObject" ) )
	{
		$dataobj = $dataobj->parent;
	}

	return $plugin->SUPER::dataobj_export_url( $dataobj, $staff );
}





1;
