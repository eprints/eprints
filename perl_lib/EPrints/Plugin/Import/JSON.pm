package EPrints::Plugin::Import::JSON;

=head1 NAME

EPrints::Plugin::Import::JSON - JSON Import Plugin

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

Import JSON documents into EPrints. Assumes a hash with appropriate key-value pairs.

=cut

use EPrints::Plugin::Import::TextFile;
use strict;
use warnings;
use autodie;

use JSON;

our @ISA = ('EPrints::Plugin::Import::TextFile');

sub new {
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);

    $self->{name} = "JSON";
    $self->{visible} = "all";
    $self->{produce} = [ "list/*", "dataobj/*" ];
    $self->{accept} = ["application/json; charset=utf-8", "sword:application/json"];

    my $rc = EPrints::Utils::require_if_exists('JSON');

    unless ($rc) {
        $self->{visible} = '';
        $self->{error} = "Failed to load required module JSON.";
    }

    return $self;
}

sub can_action { 1 };

=head1 METHODS

=head2 input_fh

Given a filehandle, opens it, reads the JSON document, imports the given array
of EPrints, then returns an EPrints::List of the imported documents.

=cut

sub input_fh
{
	my( $self, %opts ) = @_;

	my $json;
	{
		# Read entire file into string
		my $fh = $opts{fh};
		local $/ = undef;
		$json = <$fh>;
	}

	my $json_objects;
	eval {
		$json_objects = decode_json( $json );
	};

	if( $@ )
	{
		$self->error( "JSON Import Error: $@" );
		return undef;
	}

	$json_objects = [$json_objects] if( ref( $json_objects ) ne 'ARRAY' );
	
	my @ids;
	foreach my $jobj ( @{ $json_objects || [] } )
	{
		my $data;
		eval {
			$data = $self->convert_input( $opts{dataset}, $jobj );
		};
		next if( !$data || $@ );
		my $dataobj = $self->epdata_to_dataobj( $opts{dataset}, $data );
		push @ids, $dataobj->id if( defined $dataobj );
	}

	return EPrints::List->new(dataset => $opts{dataset},
			      session => $self->{session},
			      ids => \@ids);
}

=head2 convert_input

Strips any fields that do not belong in EPrints from the JSON document and
produces warnings.

=cut

sub convert_input
{
	my( $self, $dataset, $data ) = @_;

	my %clean;
	
	foreach my $field (keys %{ $data || {} })
	{
		if( !$dataset->has_field( $field ) )
		{
			$self->warning( "JSON Import: unrecognised field '$field'" );
			next;
		}
		$clean{$field} = $data->{$field};
	}

	return \%clean;
}

=head1 AUTHOR

Robert J. Berry <robert.berry@liverpool.ac.uk>

=cut

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 The University of Liverpool

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
