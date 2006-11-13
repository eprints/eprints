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

use strict;
use warnings;

use File::Temp;

our @ISA = qw( File::Temp );

=pod

=head1 NAME

EPrints::TempDir - Create temporary directories that can automatically be removed

=head1 SYNOPSIS

	use EPrints::TempDir;

	my $dir = EPrints::TempDir->new(
		TEMPLATE => 'tempXXXXX',
		DIR => 'mydir',
		UNLINK => 1);

	opendir DIR, "$dir"; # Stringifies object

=head1 DESCRIPTION

This module is basically a clone of File::Temp, but provides an object-interface to directory creation. When the object goes out of scope (and UNLINK is specified) the directory will automatically get removed.

=head1 METHODS

=over 4

=item EPrints::TempDir->new()

Create a temporary directory (see L<File::Temp>::tempdir for a description of
the arguments);

=cut

# When this object is stringified return the directory name
use overload '""' => sub { return shift->{'dir'} };

# NB this can't use my( $class ) = @_ because it may take 1 argument or named
# arguments
sub new
{
	my $class = shift;
	my $templ = 'eprintsXXXXX';
	if( 1 == @_ % 2 )
	{
		$templ = shift;
	}
	my %args = (TEMPLATE=>$templ,@_);
	$args{dir} = File::Temp::tempdir(%args);
	return bless \%args, ref($class) || $class;
}

sub DESTROY
{
	my( $self ) = @_;
	if( $self->{UNLINK} )
	{
		EPrints::Utils::rmtree($self->{dir});
	}
}

1;

__END__

=back
