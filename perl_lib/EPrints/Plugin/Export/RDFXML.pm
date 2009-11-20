package EPrints::Plugin::Export::RDFXML;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+XML";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{suffix} = ".rdf";
	$self->{mimetype} = "application/rdf+xml";
	$self->{qs} = 0.9;

	return $self;
}

# static method
sub rdf_header 
{
	my( $repository ) = @_;

	my $xmlnss = $repository->get_conf( "rdf","xmlns");

	my @r = ();
	push @r, "<?xml version='1.0' encoding='UTF-8'?>\n";
	push @r, "<!DOCTYPE rdf:RDF [\n";
	foreach my $xmlns ( keys %{$xmlnss} )
	{
		push @r, "\t<!ENTITY $xmlns '".$xmlnss->{$xmlns}."'>\n";
	}
	push @r, "]>\n";
	push @r, "<rdf:RDF";
	foreach my $xmlns ( keys %{$xmlnss} )
	{
		push @r, " xmlns:$xmlns='&$xmlns;'";
	}
	push @r, ">\n\n\n";

	return join( "", @r );
}

sub rdf_footer 
{
	return "\n\n</rdf:RDF>\n";
}

sub add_eprint_triples
{
	my( $eprint, $cache, $uri ) = @_;

	TRIP: foreach my $trip ( @{ $eprint->get_value( "rdf" ) } )
	{
		next TRIP if( $uri && $trip->{resource} ne $uri );
		my $hashkey = $trip->{object}.'^^'.($trip->{type}||"");
		$cache->{$trip->{subject}}->{$trip->{predicate}}->{$hashkey} =
			[ $trip->{object}, $trip->{type} ];
	}
}

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
		print {$opts{fh}} rdf_header( $repository );
		print {$opts{fh}} cache_to_rdfxml( $cache, $xmlns );
		print {$opts{fh}} rdf_footer( $repository );
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, rdf_header( $repository );
		push @{$r}, cache_to_rdfxml( $cache, $xmlns);
		push @{$r}, rdf_footer( $repository );
		return join( '', @{$r} );
	}
}

sub cache_to_rdfxml
{
	my( $cache, $xmlns ) = @_;

	my @l = ();
	foreach my $subject ( keys %{$cache} )
	{
		my $trips = $cache->{$subject};
		my $x_type = "rdf:Description";
		push @l, "  <$x_type rdf:about=\"".attr($subject,$xmlns)."\">\n";
		foreach my $pred ( keys %{ $trips } )
		{
			foreach my $val ( values %{$trips->{$pred}} )
			{
				my $x_pred = el($pred,$xmlns);
				if( !defined $val->[1] )
				{
					push @l, "    <$x_pred rdf:resource=\"".attr($val->[0],$xmlns)."\" />\n";
				}
				else
				{
					if( $val->[1] eq "plain" )
					{
						push @l, "    <$x_pred>";
					}
					else
					{
						push @l, "    <$x_pred rdf:datatype=\"".attr($val->[1],$xmlns)."\">";
					}
					my $x_val = val( $val->[0] );
					push @l, "$x_val</$x_pred>\n";
				}
			}
		}
		push @l, "  </$x_type>\n";
	}
	return join ('',@l);
}

sub val 
{
	my( $val ) = @_;

	$val =~ s/&/&amp;/g;
	$val =~ s/>/&gt;/g;
	$val =~ s/</&lt;/g;
	$val =~ s/"/&quot;/g;
	return $val;
}

sub el 
{
	my( $obj_id, $xmlns ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $1; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return $obj_id;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $xmlns->{$ns} )
	{
		warn "Unknown namespace prefix in RDF data: $obj_id";
		return $obj_id;
	}

	return $obj_id;
}

sub attr 
{
	my( $obj_id, $xmlns ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $1; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return $obj_id;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $xmlns->{$ns} )
	{
		warn "Unknown namespace prefix '$ns' in RDF data: $obj_id";
		return $obj_id;
	}

	return "&$ns;$value";
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


	
1;
