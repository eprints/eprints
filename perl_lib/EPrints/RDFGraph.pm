######################################################################
#
# EPrints::RDFGraph
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2010 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

=pod

=head1 NAME

B<EPrints::RDFGraph> - A set of triples

=head1 SYNOPSIS

	use EPrints::RDFGraph;

	$graph = EPrints::RDFGraph->new( repository=>$repository )

	$n = $graph->count() # returns the number of triples in the graph

	$graph->map( $function, [$info] ) # performs a function on every item in the graph. 

	$plugin_output = $graph->export( "RDFN3" ); #calls Plugin::Export::RDFN3 on the list.

=head1 DESCRIPTION

This class is used to compile a set of triples to either write to the triple dataset, or to export. It does not support all the same methods as EPrints::List, but does not require its members to exist in the database.

=head1 SEE ALSO
	L<EPrints::List>

=cut
######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{repository}
#     The current EPrints::Repository
#
#  $self->{triples}
#     The triples stored in a datastructure.
#
######################################################################

package EPrints::RDFGraph;

use strict;

use EPrints::Const;

######################################################################
=pod

=over 4

=item $list = EPrints::RDFGraph->new( repository => $repository )

Creates a new RDFGraph object in memory only. 

=cut
######################################################################

sub new
{
	my( $class, %opts ) = @_;

	my $self = {};
	$self->{repository} = $opts{repository};
	$self->{triples} = [];
	$self->{dataset} = $self->{repository}->dataset( "triple" );
	bless $self, $class;

	return $self;
}

######################################################################
=pod

=item $n = $graph->add( subject=>$subjcet, predicate=>$predicate, object=>$object, [type=>$type], [lang=>$lang], [secondary_resource=>$resource] )

Add a triple to the graph. Resource indicates the x-foo resource to which this triple belongs in addition to the dataobj that spawned it.

=cut
######################################################################

sub add
{
	my( $self, %params ) = @_;

	push @{$self->{triples}}, $self->{dataset}->make_object( $self->{repository}, \%params );
}

######################################################################
=pod

=item $n = $graph->count 

Return the number of triples added to the graph. If 2 identical triples
were added then they will be counted as "2" in this count.

=cut
######################################################################

sub count 
{
	my( $self ) = @_;

	return scalar @{$self->{triples}};
}

######################################################################
=pod

=item $graph->map( $function, [$info] )

Map the given function pointer to all the triples in the graph.

$info is a datastructure which will be passed to the function each 
time and is useful for holding or collecting state.

=cut
######################################################################

sub map
{
	my( $self, $function, $info ) = @_;	

	foreach my $triple ( @{$self->{triples}} )
	{
		&{$function}( 
			$self->{repository}, 
			$self->{dataset}, 
			$triple, 
			$info );
	}
}

######################################################################
=pod

=item $plugin_output = $graph->export( $plugin_id, %params )

Apply an output plugin to this graph of triples. If the param "fh"
is set it will send the results to a filehandle rather than return
them as a string. 

$plugin_id - the ID of the Export plugin which is to be used to process the list. e.g. "RDFXML"

$param{"fh"} = "temp_dir/my_file.txt"; - the file the results are to be output to, useful for output too large to fit into memory.


=cut
######################################################################

sub export
{
	my( $self, $out_plugin_id, %params ) = @_;

	my $plugin_id = "Export::".$out_plugin_id;
	my $plugin = $self->{session}->plugin( $plugin_id );

	unless( defined $plugin )
	{
		EPrints::abort( "Could not find output plugin $plugin_id" );
	}

	my $req_plugin_type = "list/triple";

	unless( $plugin->can_accept( $req_plugin_type ) )
	{
		EPrints::abort( 
"Plugin $plugin_id can't process $req_plugin_type data." );
	}

	return $plugin->output_list( list=>$self, %params );
}

######################################################################
=pod

=item $dataset = $list->get_dataset

Return the EPrints::DataSet which this list relates to. The 'triple'
dataset.

=cut
######################################################################

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}

######################################################################
=pod

=$item $graph->add_boilerplate_triples()

Add the boilerplate triples which are included in all RDF serialisations.

=cut
######################################################################

sub add_boilerplate_triples
{
	my( $self ) = @_;

	$self->{repository}->run_trigger( 
		EP_TRIGGER_BOILERPLATE_RDF,
		graph => $self );
}	

######################################################################
=pod

=$item $graph->add_repository_triples()

Add the repository triples for the repo. itself.

=cut
######################################################################

sub add_repository_triples
{
	my( $self ) = @_;

	$self->{repository}->run_trigger( 
		EP_TRIGGER_REPOSITORY_RDF,
		graph => $self );
}	

######################################################################
=pod

=$item $graph->add_dataobj_triples( $dataobj )

Get all triples from the dataobj and add them to the graph.

=cut
######################################################################

sub add_dataobj_triples
{
	my( $self, $dataobj ) = @_;

	my $dataset_id = $dataobj->dataset->confid;
	if( $dataset_id eq "triple" )
	{
		push @{$self->{triples}}, $dataobj;
		return;
	}

	$dataobj->dataset->run_trigger( EP_TRIGGER_RDF, graph=>$self, dataobj=>$dataobj );
}

1;

######################################################################
=pod

=back

=cut

