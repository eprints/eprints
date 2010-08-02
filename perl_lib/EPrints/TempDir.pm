######################################################################
#
# EPrints::TempDir
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################

package EPrints::TempDir;

use File::Temp;

use strict;

=pod

=head1 NAME

EPrints::TempDir - Create temporary directories that are removed automatically

=head1 DESCRIPTION

DEPRECATED

Use C<<File::Temp->newdir()>>;

=head1 SEE ALSO

L<File::Temp>

=cut

sub new
{
	my $class = shift;

	return File::Temp->newdir( @_, TMPDIR => 1 );
}

1;

__END__
