package EPrints::Plugin::Event::RDF;

use EPrints::Plugin::Event;

@ISA = qw( EPrints::Plugin::Event );

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
	my $plugin = $self->{session}->plugin( "Export::RDF" );
	my $triples = $plugin->dataobj_to_triples( $dataobj );
	foreach my $triple ( @{$triples} )
	{
		$triple->{primary_resource} = $dataobj->internal_uri;
		$triple->{secondary_resource} = $triple->{resource};
		delete $triple->{resource};
		$self->{session}->dataset( "triple" )->create_dataobj( $triple );
	}
}

1;
