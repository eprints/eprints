package EPrints::Test::RepositoryLog;

=head1 NAME

EPrints::Test::RepositoryLog - capture repository log messages

=cut

use strict;

our @logs;

{
no warnings;
sub EPrints::Repository::log
{
	my( $repo, $msg ) = @_;

	push @logs, $msg;
}
}

sub logs
{
	my @r = @logs;
	@logs = ();

	return @r;
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

