=head1 NAME

EPrints::Plugin::Import::Binary

=cut

package EPrints::Plugin::Import::Binary;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Binary file (Internal)";
	$self->{visible} = "";
	$self->{advertise} = 0;
	$self->{produce} = [qw()];
	$self->{accept} = [qw()];

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};
	my $dataset = $opts{dataset};
	my $mime_type = $opts{mime_type};
	my( $format ) = split /[;,]/, $mime_type;
	
	my $rc = 0;

	my $epdata = {
		main => $opts{filename},
		format => $format,
		files => [{
			filename => $opts{filename},
			mime_type => $format,
			filesize => -s $fh,
			_content => $fh,
		}],
	};

	if( $dataset->base_id eq "document" )
	{
	}
	elsif( $dataset->base_id eq "eprint" )
	{
		$epdata = {
			documents => [$epdata],
		};
	}
	
	my @ids;

	my $dataobj = $self->epdata_to_dataobj( $dataset, $epdata );
	push @ids, $dataobj->id if defined $dataobj;

	return EPrints::List->new(
		session => $self->{repository},
		dataset => $dataset,
		ids => \@ids );
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

