package EPrints::Plugin::Export::RDFN3;

use EPrints::Plugin::Export::RDF;
use EPrints::Plugin::Export::RDFXML;

@ISA = ( "EPrints::Plugin::Export::RDF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+N3";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint', 'list/subject', 'dataobj/subject', 'list/triple' ];
	$self->{visible} = "all";
	$self->{suffix} = ".n3";
	$self->{mimetype} = "text/n3";
	$self->{qs} = 0.84;

	return $self;
}

sub rdf_header 
{
	my( $plugin ) = @_;

	my $namespaces = $plugin->get_namespaces();

	my @r = ();
	foreach my $xmlns ( keys %{$namespaces} )
	{
		push @r, "  \@prefix $xmlns: <".$namespaces->{$xmlns}."> .\n";
	}
	push @r, "\n";
	return join( "", @r );
}

sub serialise_graph
{
	my( $plugin, $graph, %opts ) = @_;

	my $struct = $plugin->graph_to_struct( $graph );

	my @l = ();
	foreach my $subject ( EPrints::Plugin::Export::RDF::sensible_sort( keys %{$struct} ) )
	{
		#next SUBJECT if !defined $subject;
		my $trips = $struct->{$subject};
		my @preds = ();
		PREDICATE: foreach my $pred ( EPrints::Plugin::Export::RDF::sensible_sort( keys %{ $trips } ) )
		{
			my @objects = ();
			OBJECT: foreach my $val ( EPrints::Plugin::Export::RDF::sensible_sort_head( values %{$trips->{$pred}} ) )
			{
				if( !defined $val->[1] )
				{
					my $uri = $val->[0];
					next OBJECT if !defined $uri;
					push @objects, $uri;
				}
				else
				{
					my $v = $val->[0];
					$v =~ s/\\/\\\\/g;
					$v =~ s/\'/\\'/g;
					$v =~ s/\"/\\"/g;
					$v =~ s/\n/\\n/g;
					$v =~ s/\r/\\r/g;
					$v =~ s/\t/\\t/g;
					my $data = '"'.$v.'"';
					if( defined $val->[2] )
					{
						$data.='@'.$val->[2];
					}
					if( $val->[1] ne "literal" )
					{
						$data.='^^'.$val->[1];
					}
					push @objects, $data;
				}
			}
			push @preds, "\t".$pred." ".join( ",\n		", @objects );
		}
		push @l, "$subject\n".join( ";\n", @preds )." .\n\n";
		if( defined $opts{fh} )
		{
			print {$opts{fh}} join( '',@l );
			@l = ();
		}
	}
	return join ('',@l);
}

# nb. this function not currently used
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
