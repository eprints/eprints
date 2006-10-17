######################################################################
#
# EPrints::Platform
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

B<EPrints::Platform> - handles platform specific code.

=head1 DESCRIPTION

When you call a method in this class, it is sent to the appropriate
EPrints::Platform::xxx module. Usually this is 
EPrints::Platform::Unix

Which module is used is configured by the {platform} setting in
SystemSettings.pm

=over 4

=cut

package EPrints::Platform;

use strict;
no strict 'refs';

my $platform = $EPrints::SystemSettings::conf->{platform};
my $real_module = "EPrints::Platform::\u$platform";

sub chmod { return &{"$real_module::chmod"}( @_ ); }

sub chown { return &{"$real_module::chown"}( @_ ); }

1;
