######################################################################
#
# EPrints::MetaField::Langid;
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

=pod

=head1 NAME

B<EPrints::MetaField::Langid> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Langid;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;


sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." VARCHAR(16)".($notnull?" NOT NULL":"");
}


######################################################################
1;
