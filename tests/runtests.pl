#!/usr/bin/perl -w  

use Test::Harness;
use strict;

my $dir = "/opt/eprints3/tests";
chdir( $dir );
my $dh;
my @files = ();
opendir( $dh, $dir ) || die "can't read dir: $dir";
while( my $file = readdir($dh ) )
{
	next if( $file !~ m/\.pl$/ );
	next if( $file eq "runtests.pl" );
	push @files, $file;
}
closedir($dh);

runtests(@files);
