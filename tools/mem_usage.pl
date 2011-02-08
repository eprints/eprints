#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../perl_lib";

use EPrints;
use EPrints::Test::ModuleSize;

use strict;
use warnings;

my $repo = @ARGV ? EPrints->new->repository( $ARGV[0] ) : undef;

my $sizes = EPrints::Test::ModuleSize::scan();
foreach my $name (sort { $sizes->{$b} <=> $sizes->{$a} } keys %$sizes)
{
	print sprintf("%40s %s\n", $name, EPrints::Utils::human_filesize( $sizes->{$name} ));
}
