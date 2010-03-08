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

	return $plugin->{session}->get_conf( "rdf","xmlns");
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

	my $repository = $plugin->{session};

	my $dataobj_uri = "<".$dataobj->uri.">";
	my $graph = EPrints::RDFGraph->new( repository=>$repository );
	$graph->add_boilerplate_triples();
	$graph->add( 
		  subject => "<>", 
		predicate => "foaf:primaryTopic", 
		   object => "<".$dataobj->uri.">" );
	$graph->add_dataobj_triples( $dataobj );

	return $plugin->output_graph( $graph );
}

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $graph = EPrints::RDFGraph->new( repository=>$plugin->{session} );
	$graph->add_boilerplate_triples();
	
	$opts{list}->map( sub {
		my( $repository, $dataset, $dataobj ) = @_;

		$graph->add_dataobj_triples( $dataobj );
	} );

	return $plugin->output_graph( $graph, %opts );
}

sub output_graph
{
	my( $plugin, $graph, %opts ) = @_;

	if( defined $opts{fh} )
	{
		print {$opts{fh}} $plugin->rdf_header();
		print {$opts{fh}} $plugin->serialise_graph( $graph );
		print {$opts{fh}} $plugin->rdf_footer();
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, $plugin->rdf_header();
		push @{$r}, $plugin->serialise_graph( $graph );
		push @{$r}, $plugin->rdf_footer();
		return join( '', @{$r} );
	}

}

sub graph_to_struct
{
	my( $plugin, $graph ) = @_;

	my $tripletree = {};
	$graph->map( sub {
		my( $repository, $dataset, $triple ) = @_;
		my $t = $triple->get_data;
		my $hashkey = ($t->{object}||"").'^^'.($t->{type}||"").'@'.($t->{lang}||"");
		$tripletree->{$t->{subject}}->{$t->{predicate}}->{$hashkey} =
			[ $t->{object}||"", $t->{type}, $t->{lang} ];
	} );
	return $tripletree;
}
	





1;
