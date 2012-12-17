=head1 NAME

EPrints::Apache::MapToStorage::XPage - process .xpage and generate a static copy

=head1 DESCRIPTION

=over 4

=cut

package EPrints::Apache::MapToStorage::XPage;

use EPrints::Const qw( :http );
use base qw( EPrints::Apache::MapToStorage );

use strict;

sub handler
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

	my $localpath = $r->pnotes( "localpath" );
	my $langid = $r->pnotes( "langid" );

	$localpath =~ s/\.html$//;

	my @static_dirs = $repo->get_static_dirs( $langid );

	my $source = EPrints::Apache::MapToStorage::find_source_file( "$localpath.xpage", @static_dirs );
	return DECLINED if !defined $source;

	my $target = $repo->config( "htdocs_path" )."/".$langid.$localpath;

	if( !-e "$target.page" || (stat("$target.page"))[9] < (stat($source))[9] )
	{
		unlink("$target.page");
		EPrints::Update::Static::copy_xpage( $repo, $source, "$target.html", {} );
	}

	if( -e "$target.page" )
	{
		my $ua = $r->headers_in->{'User-Agent'};
		if( $ua && $ua =~ /MSIE ([0-9]{1,}[\.0-9]{0,})/ && $1 >= 8.0 )
		{
			$r->headers_out->{'X-UA-Compatible'} = "IE=9";
		}

		$r->filename( "$target.html" );
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => [ 'EPrints::Apache::Template' ] );
		return OK;
	}

	return DECLINED;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

