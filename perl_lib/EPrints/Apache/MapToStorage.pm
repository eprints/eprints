=head1 NAME

EPrints::Apache::MapToStorage - delivery static files

=head1 DESCRIPTION

Map requests for plain static files to the file system.

=over 4

=cut

package EPrints::Apache::MapToStorage;

use EPrints::Const qw( :http );

use File::Find;

use strict;

sub handler
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

	my $localpath = $r->pnotes( "localpath" );

	my @static_dirs = $repo->get_static_dirs( $r->pnotes( "langid" ) );

	$r->filename( find_source_file( $localpath, @static_dirs ) );

	set_expires( $repo, $r );

	return DECLINED;
}

sub set_expires
{
	my( $repo, $r ) = @_;

	# set all static files to +1 month expiry
	$r->headers_out->{Expires} = Apache2::Util::ht_time(
			$r->pool,
			time + 30 * 86400
		);
	# let Firefox cache secure, static files
	if( $repo->get_secure )
	{
		$r->headers_out->{'Cache-Control'} = 'public';
	}
}

sub find_source_file
{
	my( $localpath, @dirs ) = @_;

	my $filename;

	DIR: foreach my $dir ( @dirs )
	{
		if( -e $dir.$localpath )
		{
			$filename = $dir.$localpath;
			last DIR;
		}
	}

	return $filename;
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

