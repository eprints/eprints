
# sf2 - used by CRUD to import files 
# based on Import::Binary
# might not be necessary but useful for dev/testing

package EPrints::Plugin::Import::File;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "File (Internal)";
	$self->{visible} = "all";
	$self->{produce} = ["dataobj/file"];
	$self->{accept} = [ "application/x-www-form-urlencoded", "multipart/form-data" ];

	$self->{arguments}->{filename} = undef;
	$self->{arguments}->{mime_type} = undef;

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};

	my $dataset = $self->{repository}->dataset( 'file' ) or EPrints->abort( 'Dataset "file" does not exist' );

	my $filename = $opts{filename} or EPrints->abort( "Requires filename argument" );
	my $mime_type = $opts{mime_type};
	my( $format ) = split /[;,]/, $mime_type;
	
	my $epdata = {
		filename => "$filename",
		mime_type => $format,
		filesize => -s $fh,
		_content => $fh,
	};
	
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

