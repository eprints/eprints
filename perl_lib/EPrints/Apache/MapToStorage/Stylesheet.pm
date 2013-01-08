=head1 NAME

EPrints::Apache::MapToStorage::Stylesheet - generate auto.css

=head1 DESCRIPTION

=over 4

=cut

package EPrints::Apache::MapToStorage::Stylesheet;

use EPrints::Const qw( :http );
use base qw( EPrints::Apache::MapToStorage );

use strict;

sub handler
{
	my( $r ) = @_;

	my $repo = EPrints->new->current_repository;

	my $langid = $r->pnotes( "langid" );

	my @static_dirs = $repo->get_static_dirs( $langid );

	my $target = $repo->config( "htdocs_path" )."/".$langid."/style/auto.css";
	$r->filename( $target );

	EPrints::Update::Static::update_auto( $target, "css", [
			map { "$_/style/auto" } @static_dirs
		]);

	EPrints::Apache::MapToStorage::set_expires( $repo, $r );

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

