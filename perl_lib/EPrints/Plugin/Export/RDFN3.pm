package EPrints::Plugin::Export::RDFN3;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+N3";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".n3";
	$self->{mimetype} = "text/plain";
	$self->{qs} = 0.9;

	return $self;
}

# static method
sub n3_header 
{
	my( $repository ) = @_;

	my $xmlnss = $repository->get_conf( "rdf","xmlns");

	my @r = ();
	foreach my $xmlns ( keys %{$xmlnss} )
	{
		push @r, "  \@prefix $xmlns: <".$xmlnss->{$xmlns}."> .\n";
	}

	return join( "", @r );
}


sub add_eprint_triples
{
	my( $eprint, $cache, $uri ) = @_;

	TRIP: foreach my $trip ( @{ $eprint->get_value( "rdf" ) } )
	{
		next TRIP if( $uri && $trip->{resource} ne $uri );
		my $hashkey = ($trip->{object}||"").'^^'.($trip->{type}||"");
		$cache->{$trip->{subject}}->{$trip->{predicate}}->{$hashkey} =
			[ $trip->{object}||"", $trip->{type} ];
	}
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $repository = $plugin->{session}->get_repository;

	my $cache = {};
	add_eprint_triples( $dataobj, $cache );
	my $xmlns = $repository->get_conf( "rdf","xmlns");

	return $plugin->output_triple_cache( $cache, $xmlns );
}

# Later this may print the header then output each batch of, say, 100
# eprints so that it doesn't take up crazy memory.
sub output_list
{
	my( $plugin, %opts ) = @_;

	my $cache = {};
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;

		add_eprint_triples( $dataobj, $cache );
	} );

	return $plugin->output_triple_cache( $cache, %opts );
}

sub output_triple_cache
{
	my( $plugin, $cache, %opts ) = @_;

	my $repository = $plugin->{session}->get_repository;
	my $xmlns = $repository->get_conf( "rdf","xmlns");

	if( defined $opts{fh} )
	{
		print {$opts{fh}} n3_header( $repository );
		print {$opts{fh}} cache_to_n3( $cache, $xmlns );
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, n3_header( $repository );
		push @{$r}, cache_to_n3( $cache, $xmlns);
		return join( '', @{$r} );
	}
}

sub cache_to_n3
{
	my( $cache, $xmlns ) = @_;

	my @l = ();
	SUBJECT: foreach my $subject ( keys %{$cache} )
	{
		my $trips = $cache->{$subject};
		my @preds = ();
		PREDICATE: foreach my $pred ( keys %{ $trips } )
		{
			my @objects = ();
			OBJECT: foreach my $val ( values %{$trips->{$pred}} )
			{
				if( !defined $val->[1] )
				{
					my $uri = expand_uri($val->[0],$xmlns);
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
					if( $val->[1] ne "plain" )
					{
						push @objects, '"'.$v.'"^^'.$val->[1];;
					}
					else
					{
						push @objects, '"'.$v.'"';
					}
				}
			}
			push @preds, "\t".$pred." ".join( ",\n		", @objects );
		}
		my $uri = expand_uri($subject,$xmlns);
		next OBJECT if !defined $uri;
		push @l, "$uri\n".join( ";\n", @preds )." .\n";
	}
	return join ('',@l);
}

sub expand_uri 
{
	my( $obj_id, $xmlns ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $obj_id; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $xmlns->{$ns} )
	{
		warn "Unknown namespace prefix in RDF data: $obj_id";
		return;
	}

	return "<".$xmlns->{$ns}.$value.">";
}


	
1;
