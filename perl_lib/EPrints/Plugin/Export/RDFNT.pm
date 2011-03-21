=head1 NAME

EPrints::Plugin::Export::RDFNT

=cut

package EPrints::Plugin::Export::RDFNT;

use EPrints::Plugin::Export::RDF;
use EPrints::Plugin::Export::RDFXML;

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
	my( $plugin, $graph, %opts ) = @_;

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
		if( defined $opts{fh} )
		{
			print {$opts{fh}} join( '',@l );
			@l = ();
		}
	});
	
	return join ('',@l);
}

sub expand_uri 
{
	my( $obj_id, $namespaces ) = @_;

	if( $obj_id =~ /^<(.*)>$/ ) { return "<".uriesc($1).">"; }

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

	return "<".$namespaces->{$ns}.uriesc($value).">";
}

# just deal with < > \n and \r
sub uriesc
{
	my( $uri ) = @_;

	$uri =~ s/([<>\n\r])/sprintf( "%%%02X", ord($1) )/ge;

	return $uri;
}

	
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

