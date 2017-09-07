=head1 NAME

EPrints::Apache::RobotsTxt

=cut

######################################################################
#
# EPrints::Apache::RobotsTxt
#
######################################################################
#
#
######################################################################

package EPrints::Apache::RobotsTxt;

use EPrints::Apache::AnApache; # exports apache constants

use strict;
use warnings;

sub handler
{
	my( $r ) = @_;

	my $repository = $EPrints::HANDLE->current_repository;


	my $langid = EPrints::Session::get_session_language( $repository, $r );
	my @static_dirs = $repository->get_static_dirs( $langid );
	my $robots;
	foreach my $static_dir ( @static_dirs )
	{
		my $file = "$static_dir/robots.txt";
		next if( !-e $file );
		
		open( ROBOTS, $file ) || EPrints::abort( "Can't read $file: $!" );
		$robots = join( "", <ROBOTS> );
		close ROBOTS;
		last;
	}	
	if( !defined $robots )
	{
		$http_cgiroot = $repository->config( 'http_cgiroot' );
		$https_cgiroot = $repository->config( 'https_cgiroot' );
		$robots = <<END;
User-agent: *
Disallow: $http_cgiroot
END
		if( $http_cgiroot ne $https_cgiroot )
		{
			$robots .= "\nDisallow: $https_cgiroot";
		}
	}

	my $sitemap = "Sitemap: ".$repository->config( 'http_url' )."/sitemap.xml";
	if( ! ($robots =~ s/User-agent: \*\n/User-agent: \*\n$sitemap\n/ ) )
	{
		$robots = "User-agent: \*\n$sitemap\n\n$robots";	
	}

	binmode( *STDOUT, ":utf8" );
	$repository->send_http_header( "content_type"=>"text/plain; charset=UTF-8" );
	print $robots;

	return DONE;
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

