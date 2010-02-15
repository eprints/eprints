package EPrints::Plugin::Export::RDFXML;

# eprint needs magic documents field

# documents needs magic files field

use EPrints::Plugin::Export::RDF;

@ISA = ( "EPrints::Plugin::Export::RDF" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "RDF+XML";
	$self->{accept} = [ 'list/eprint', 'dataobj/eprint', 'list/subject', 'dataobj/subject' ];
	$self->{visible} = "all";
	$self->{suffix} = ".rdf";
	$self->{mimetype} = "application/rdf+xml";
	$self->{qs} = 0.85;

	return $self;
}


# static method
sub rdf_header 
{
	my( $repository, $namespaces ) = @_;

	my @r = ();
	push @r, "<?xml version='1.0' encoding='UTF-8'?>\n";
	push @r, "<!DOCTYPE rdf:RDF [\n";
	foreach my $xmlns ( keys %{$namespaces} )
	{
		push @r, "\t<!ENTITY $xmlns '".$namespaces->{$xmlns}."'>\n";
	}
	push @r, "]>\n";
	push @r, "<rdf:RDF";
	foreach my $xmlns ( keys %{$namespaces} )
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

sub output_list
{
	my( $plugin, %opts ) = @_;

	my $cache = {};
	$plugin->cache_general_triples( $cache );
	$opts{list}->map( sub {
		my( $session, $dataset, $dataobj ) = @_;

		$plugin->cache_dataobj_triples( $dataobj, $cache );
	} );

	return $plugin->output_triple_cache( $cache, %opts );
}

sub output_triple_cache
{
	my( $plugin, $cache, %opts ) = @_;

	my $repository = $plugin->{session}->get_repository;
	my $namespaces = $plugin->get_namespaces();

	if( defined $opts{fh} )
	{
		print {$opts{fh}} rdf_header( $repository, $namespaces );
		print {$opts{fh}} cache_to_rdfxml( $cache, $namespaces );
		print {$opts{fh}} rdf_footer( $repository );
		return undef;
	}
	else
	{
		my $r = [];
		push @{$r}, rdf_header( $repository, $namespaces );
		push @{$r}, cache_to_rdfxml( $cache, $namespaces);
		push @{$r}, rdf_footer( $repository );
		return join( '', @{$r} );
	}
}

sub cache_to_rdfxml
{
	my( $cache, $namespaces ) = @_;

	my @l = ();
	foreach my $subject ( sort keys %{$cache} )
	{
		my $trips = $cache->{$subject};
		my $x_type = "rdf:Description";
		push @l, "  <$x_type rdf:about=\"".attr($subject,$namespaces)."\">\n";
		foreach my $pred ( sort keys %{ $trips } )
		{
			foreach my $val ( sort values %{$trips->{$pred}} )
			{
				my $x_pred = el($pred,$namespaces);
				if( $x_pred =~ m/^[a-z0-9_-]+:[a-z0-9_-]+$/i )
				{
					push @l, "    <$x_pred";
				}
				elsif( $x_pred =~ m/^(.*[^a-z0-9_-])([a-z0-9_-]+)$/i )
				{
					push @l, "    <nsx:$2 xmlns:nsx='$1'";
				}
				else
				{
					warn "Odd subject ID: '$x_pred'";
					next;
				}
				if( !defined $val->[1] )
				{
					push @l, " rdf:resource=\"".attr($val->[0],$namespaces)."\" />\n";
				}
				else
				{
					if( $val->[1] ne "literal" )
					{
						push @l, " rdf:datatype=\"".attr($val->[1],$namespaces)."\"";
					}
					if( defined $val->[2] )
					{
						push @l, " xml:lang=\"".$val->[2]."\"";
					}
					my $x_val = val( $val->[0] );
					push @l, ">$x_val</$x_pred>\n";
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
	my( $obj_id, $namespaces ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $1; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return $obj_id;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $namespaces->{$ns} )
	{
		warn "Unknown namespace prefix '$ns' in RDF data: $obj_id";
		return $obj_id;
	}

	return $obj_id;
}

sub attr 
{
	my( $obj_id, $namespaces ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return $1; }

	if( ! $obj_id =~ m/:/ ) { 
		warn "Neither <uri> nor namespace prefix in RDF data: $obj_id";
		return $obj_id;
	}

	my( $ns, $value ) = split( /:/, $obj_id, 2 );
	if( !defined $namespaces->{$ns} )
	{
		warn "Unknown namespace prefix '$ns' in RDF data: $obj_id";
		return $obj_id;
	}

	return "&$ns;$value";
}

sub initialise_fh
{
	my( $plugin, $fh ) = @_;

	binmode($fh, ":utf8");
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $repository = $plugin->{session}->get_repository;

	my $cache = {};
	$plugin->cache_general_triples( $cache );
	$plugin->cache_dataobj_triples( $dataobj, $cache );
	my $namespaces = $plugin->get_namespaces();

	return $plugin->output_triple_cache( $cache, $namespaces );
}

1;
