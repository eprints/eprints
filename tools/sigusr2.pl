#!/usr/bin/perl -w

use strict;

use EPrints;

exit if fork(); # go into background

print <<EOH;
Sleeping for 1000 seconds

Execute:
\$ kill -USR2 $$;

You should see the debug output ending with:
main::hanging_sub called at tools/sigusr2.pl line 11
EOH

&hanging_sub;

sub hanging_sub
{
	sleep(1000);
}
