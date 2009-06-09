######################################################################
#
# EPrints::MetaField::Timestamp;
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

B<EPrints::MetaField::Timestamp> - a date/time

=head1 DESCRIPTION

A date/time that defaults to the current time in UTC.

=over 4

=cut


package EPrints::MetaField::Timestamp;

use strict;
use warnings;

use EPrints::MetaField::Time;
our @ISA = qw( EPrints::MetaField::Time );

sub get_default_value
{
	return EPrints::Time::get_iso_timestamp();
}

######################################################################
1;
######################################################################
#
# EPrints::MetaField::Timestamp;
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

B<EPrints::MetaField::Timestamp> - a date/time

=head1 DESCRIPTION

A date/time that defaults to the current time in UTC.

=over 4

=cut


package EPrints::MetaField::Timestamp;

use strict;
use warnings;

use EPrints::MetaField::Time;
our @ISA = qw( EPrints::MetaField::Time );

sub get_default_value
{
	return EPrints::Time::get_iso_timestamp();
}

######################################################################
1;
