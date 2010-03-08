package EPrints::Plugin::Export::RDFNT;

use EPrints::Plugin::Export::RDF;
use EPrints::Plugin::Export::RDFXML

@ISA = ( "EPrints::Plugin::Export::RDF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+N-Triples";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint', 'list/subject', 'dataobj/subject', 'list/triple' ];
	$self->{visible} = "all";
	$self->{suffix} = ".nt";
	$self->{mimetype} = "text/plain";
	$self->{qs} = 0.5;

	return $self;
}

sub serialise_graph
{
	my( $plugin, $graph ) = @_;

	my $namespaces = $plugin->get_namespaces();
	my @l = ();
	$graph->map( sub {
		my( $repository, $dataset, $triple ) = @_;
		my $t = $triple->get_data;
		my $s_uri = expand_uri( $t->{subject}, $namespaces );
		my $p_uri = expand_uri( $t->{predicate}, $namespaces );
		if( !defined $t->{type} )
		{
			my $uri = expand_uri($t->{object},$namespaces);
			push @l, "$s_uri $p_uri $uri .\n";
			return;
		}

		my $v = $t->{object};
		$v =~ s/\\/\\\\/g;
		$v =~ s/\'/\\'/g;
		$v =~ s/\"/\\"/g;
		$v =~ s/\n/\\n/g;
		$v =~ s/\r/\\r/g;
		$v =~ s/\t/\\t/g;
		my $data = '"'.$v.'"';
		if( defined $t->{lang} )
		{
			$data.='@'.$t->{lang};
		}
		if( $t->{type} ne "literal" )
		{
			$data.='^^'.expand_uri( $t->{type}, $namespaces );
		}
		push @l, "$s_uri $p_uri $data .\n";
	});
	
	return join ('',@l);
}

sub expand_uri 
{
	my( $obj_id, $namespaces ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $obj_id; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $namespaces->{$ns} )
	{
		warn "Unknown namespace prefix '$ns' in RDF data: $obj_id";
		return;
	}

	return "<".$namespaces->{$ns}.$value.">";
}

	
1;
