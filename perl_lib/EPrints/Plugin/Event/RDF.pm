package EPrints::Plugin::Event::RDF;

use EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin::Event );

use strict;

sub clear_triples
{
	my( $self, $dataobj ) = @_;

	# clear
	
	my $list = $self->{session}->dataset( "triple" )->search( 
		filters => [
			{
				meta_fields => [qw/ primary_resource /],
				value => $dataobj->internal_uri,
			}
		],
	);

	$list->map( sub {
		my( $repository, $dataset, $dataobj ) = @_;
		$dataobj->remove;
	} );
}

sub update_triples
{
	my( $self, $dataobj ) = @_;

	$self->clear_triples( $dataobj );

	# modded
	my $graph = EPrints::RDFGraph->new( repository=>$self->{session} );
	$graph->add_dataobj_triples( $dataobj );

	my $namespaces = $self->{session}->get_conf( "rdf","xmlns");

	$graph->map( sub {
		my( $repository, $dataset, $triple ) = @_;
		my %data = %{$triple->get_data};
		$data{primary_resource}= '<'.$dataobj->uri.'>';
		uri_compress( \$data{primary_resource}, $namespaces );
		if( defined $data{secondary_resource} )
		{
			uri_compress( \$data{secondary_resource}, $namespaces );
		}
		uri_compress( \$data{subject}, $namespaces );
		uri_compress( \$data{predicate}, $namespaces );
		if( !$data{type} )
		{
			uri_compress( \$data{object}, $namespaces );
		}
		if( $data{type} )
		{
			uri_compress( \$data{type}, $namespaces );
		}
		delete $data{tripleid};
		$self->{session}->dataset( "triple" )->create_dataobj( \%data );
	});
}

sub uri_compress
{
	my( $str, $namespaces ) = @_;

	return if( substr( $$str, 0, 1 ) ne "<" );
	foreach my $short ( keys %{$namespaces} )
	{
		my $long = $namespaces->{$short};
		my $l = length( $long );
		if( substr( $$str, 1, $l ) eq $long )
		{
			$$str = $short.":".substr( $$str, 1+$l, length($$str)-$l-2);
			return;
		}
	}
}

1;
