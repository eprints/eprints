######################################################################
#
# EPrints::XHTML
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2009 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
#
######################################################################


=pod

=head1 NAME

B<EPrints::XHTML> - XHTML Module

=head1 DESCRIPTION

The XHTML object facilitates the creation of XHTML objects.

=over 4

=cut

package EPrints::XHTML;

use strict;

# $xhtml = new EPrints::XHTML( $repository )
#
# Contructor, should be called by Repository only.

sub new($$)
{
	my( $class, $repository ) = @_;

	my $self = bless { repository => $repository }, $class;

	return $self;
}

######################################################################
=pod

=back

=cut
######################################################################

1;
