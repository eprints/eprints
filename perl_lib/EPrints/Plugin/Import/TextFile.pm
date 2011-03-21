=head1 NAME

EPrints::Plugin::Import::TextFile

=cut

package EPrints::Plugin::Import::TextFile;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

if( $^V gt v5.8.0 )
{
	eval "use File::BOM";
}

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Base text input plugin: This should have been subclassed";
	$self->{visible} = "all";

	return $self;
}

sub input_fh
{
	my( $self, %opts ) = @_;

	my $fh = $opts{fh};

	if( $^V gt v5.8.0 and seek( $fh, 0, 1 ) )
	{
		# Strip the Byte Order Mark and set the encoding appropriately
		# See http://en.wikipedia.org/wiki/Byte_Order_Mark
		File::BOM::defuse($fh);

		# Read a line from the file handle and reset the fp
		my $start = tell( $fh );
		my $line = <$fh>;
		seek( $fh, $start, 0 )
			or die "Unable to reset file handle for crlf detection.";

		# If the line ends with return add the crlf layer
		if( $line =~ /\r$/ )
		{
			binmode( $fh, ":crlf" );
		}	
	}

	return $self->input_text_fh( %opts );
}

sub input_text_fh
{
	my( $self, %opts ) = @_;

	return undef;
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

