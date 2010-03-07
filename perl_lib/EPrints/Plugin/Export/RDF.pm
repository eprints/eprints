package EPrints::Plugin::Export::RDF;

# This virtual super-class supports RDF serialisations

use EPrints::Plugin::Export::TextFile;

our @ISA = qw( EPrints::Plugin::Export::TextFile );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	return $self;
}

sub get_namespaces
{
	my( $plugin ) = @_;

	return $plugin->{session}->get_repository->get_conf( "rdf","xmlns");
}

sub rdf_header 
{
	my( $plugin ) = @_;

	return "";
}

sub rdf_footer 
{
	my( $plugin ) = @_;

	return "";
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

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $repository = $plugin->{session}->get_repository;

	my $triples = {};
	$plugin->cache_general_triples( $triples );
	my $dataobj_uri = $dataobj->get_uri;
	$triples->{"<>"}->{"foaf:primaryTopic"}->{$dataobj_uri."^^@"} = [$dataobj_uri,undef,undef];
	$plugin->cache_dataobj_triples( $dataobj, $triples );

	return $plugin->output_triples( $triples );
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $triples = {};
	$plugin->cache_general_triples( $triples );
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;

		$plugin->cache_dataobj_triples( $dataobj, $triples );
	} );

	return $plugin->output_triples( $triples, %opts );
}

# Takes a structured list of triples and outputs them as a serialised
# RDF document.

sub output_triples
{
	my( $plugin, $triples, %opts ) = @_;

	my $namespaces = $plugin->get_namespaces();

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $plugin->rdf_header();
		print {$opts{fh}} $plugin->serialise_triples( $triples );
		print {$opts{fh}} $plugin->rdf_footer();
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, $plugin->rdf_header();
		push @{$r}, $plugin->serialise_triples( $triples );
		push @{$r}, $plugin->rdf_footer();
		return join( '', @{$r} );
	}
}



#### Candidates for refactoring

sub dataobj_to_triples
{
	my( $plugin, $dataobj ) = @_;

	my $triples = {};
	my $dataset_id = $dataobj->dataset->confid;
	$plugin->{session}->run_trigger( "rdf_triples_$dataset_id", dataobj=>$dataobj, triples=>$triples );

	my $t = [];
	foreach my $resource ( keys %{$triples} )
	{
		foreach my $spo ( @{$triples->{$resource}} )
		{
			push @{$t}, {
				resource=>$resource,
				subject=>$spo->[0],
				predicate=>$spo->[1],
				object=>$spo->[2],
				type=>$spo->[3],
				lang=>$spo->[4] };
		}
	}
	return $t;
}




sub cache_dataobj_triples
{
	my( $plugin, $dataobj, $triples, $uri ) = @_;

	TRIP: foreach my $triple ( @{ $plugin->dataobj_to_triples( $dataobj ) } )
	{
		next TRIP if( $uri && $triple->{resource} ne $uri );
		my $hashkey = ($triple->{object}||"").'^^'.($triple->{type}||"").'@'.($triple->{lang}||"");
		$triples->{$triple->{subject}}->{$triple->{predicate}}->{$hashkey} =
			[ $triple->{object}||"", $triple->{type}, $triple->{lang} ];
	}
}

sub cache_general_triples
{
	my( $plugin, $triples ) = @_;

	$plugin->cache_trigger_triples( $triples, "general" );
}

sub cache_trigger_triples
{
	my( $plugin, $triples, $trigger ) = @_;

	my $tset = {};
	$plugin->{session}->run_trigger( "rdf_triples_$trigger", triples=>$tset );

	foreach my $resource ( keys %{$tset} )
	{
		foreach my $spo ( @{$tset->{$resource}} )
		{
			my $trip = {
				resource=>$resource,
				subject=>$spo->[0],
				predicate=>$spo->[1],
				object=>$spo->[2],
				type=>$spo->[3],
				lang=>$spo->[4] };
			my $hashkey = ($trip->{object}||"").'^^'.($trip->{type}||"").'@'.($trip->{lang}||"");
			$triples->{$trip->{subject}}->{$trip->{predicate}}->{$hashkey} =
				[ $trip->{object}||"", $trip->{type}, $trip->{lang} ];
		}
	}
}



1;
