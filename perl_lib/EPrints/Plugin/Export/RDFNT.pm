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
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint', 'list/subject', 'dataobj/subject', 'triples' ];
	$self->{visible} = "all";
	$self->{suffix} = ".nt";
	$self->{mimetype} = "text/plain";
	$self->{qs} = 0.5;

	return $self;
}

sub serialise_triples
{
	my( $plugin, $triples ) = @_;

	my $namespaces = $plugin->get_namespaces();
	my @l = ();
	SUBJECT: foreach my $subject ( keys %{$triples} )
	{
		my $s_uri = expand_uri( $subject, $namespaces );
		next SUBJECT if !defined $s_uri;
		my $trips = $triples->{$subject};
		PREDICATE: foreach my $pred ( keys %{ $trips } )
		{
			my $p_uri = expand_uri( $pred, $namespaces );
			next PREDICATE if !defined $p_uri;
			OBJECT: foreach my $val ( values %{$trips->{$pred}} )
			{
				if( !defined $val->[1] )
				{
					my $uri = expand_uri($val->[0],$namespaces);
					next OBJECT if !defined $uri;
					push @l, "$s_uri $p_uri $uri .\n";
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
						$data.='^^'.expand_uri( $val->[1], $namespaces );
					}
					push @l, "$s_uri $p_uri $data .\n";
				}
			}
		}
	}
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
