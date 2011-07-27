=head1 NAME

EPrints::Plugin::Storage::EPM - epm relative-stored files

=head1 DESCRIPTION

See L<EPrints::Plugin::Storage> for available methods.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::Storage::EPM;

use URI;
use URI::Escape;
use Fcntl 'SEEK_SET';

use EPrints::Plugin::Storage::Local;

@ISA = ( "EPrints::Plugin::Storage::Local" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "EPM system installation";
	$self->{storage_class} = "a_epm_disk_storage";
	$self->{position} = 1000;

	return $self;
}

sub _filename
{
	my( $self, $fileobj, $filename ) = @_;

	my $libpath = $self->{repository}->config( "base_path" ) . "/lib";

	# temp files for installation
	if( defined $filename )
	{
		my $filepath = $filename;
		$filepath =~ s/[^\\\/]+$//;
		return( substr($filepath,0,-1), substr($filename,length($filepath)) );
	}

	return(
		$libpath,
		$fileobj->value( "filename" ),
	);
}

=back

=cut

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

