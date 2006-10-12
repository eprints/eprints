######################################################################
#
# EPrints::Session
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
use File::Path qw/ rmtree /;

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

=head1 DESCRIPTION

This module is basically a clone of File::Temp, but provides an object-interface to directory creation.

=head1 METHODS

=over 4

=item EPrints::TempDir->new()

Create a temporary directory (see File::Temp for a description of the relevant
arguments);

=cut

# When this object is used in string context return the directory
use overload '""' => sub { return shift->{'dir'} };

sub new {
	my $class = shift;
	my $templ = 'eprintsXXXXX';
	if( 1 == @_ % 2 ) {
		$templ = shift;
	}
	my %args = (TEMPLATE=>$templ,@_);
	$args{dir} = File::Temp::tempdir(%args);
	return bless \%args, ref($class) || $class;
}

sub DESTROY
{
	my $self = shift;
	if( $self->{UNLINK} ) {
		rmtree($self->{dir},0,0);
	}
}

1;

__END__

=back
