######################################################################
#
# EPrint Version
#
#  Holds information about the current version of EPrints.
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

package EPrints::Version;

use strict;
use Unicode::String qw(utf8 latin1 utf16);


# GLOBAL SITE REVISION NUMBER
$EPrints::Version::eprints_software_version = latin1("Version 2.0 (pre-alpha)");

1;
