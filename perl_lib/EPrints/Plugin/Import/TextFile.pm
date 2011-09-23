=head1 NAME

EPrints::Plugin::Import::TextFile

=cut

package EPrints::Plugin::Import::TextFile;

use Encode;

use strict;

our @ISA = qw/ EPrints::Plugin::Import /;

$EPrints::Plugin::Import::DISABLE = 1;

our %BOM2ENC = map { Encode::encode($_, "\x{feff}") => $_ } qw(
		UTF-8
		UTF-16BE
		UTF-16LE
		UTF-32BE
		UTF-32LE
	);

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
		use bytes;

		my $line = <$fh>;
		seek( $fh, 0, 0 )
			or die "Unable to reset file handle after BOM/CRLF read";

		# Detect the Byte Order Mark and set the encoding appropriately
		# See http://en.wikipedia.org/wiki/Byte_Order_Mark
		for(2..4)
		{
			if( defined( my $enc = $BOM2ENC{substr($line,0,$_)} ) )
			{
				seek( $fh, $_, 0 );
				binmode($fh, ":encoding($enc)");
				last;
			}
		}

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

