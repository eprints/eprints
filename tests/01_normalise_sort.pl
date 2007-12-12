#!/usr/bin/perl

use Test::More tests => 1;

my @values = qw( ya zb yc );

use EPrints;

@values = sort { &EPrints::MetaField::_normalcmp($a,$b) } @values;

is($values[1],"yc","y != z, ticket #2944");
