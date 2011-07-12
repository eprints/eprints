#!/usr/bin/perl

use Test::More tests => 7;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repo = EPrints::Test::get_test_repository();

my $base64 = <DATA>;

my $dataset = $repo->dataset( "epm" );

my $epm = $dataset->make_dataobj({
	version => '4.2.3',
	documents => [{
		content => "install",
		format => "other",
		main => "main.bin",
		files => [{
			data => $base64,
			filename => "main.bin",
			mime_type => "application/octet-stream",
		}],
	}],
});
$epm->_upgrade;

ok($epm->serialise(1) =~ /$base64/, "serialise with files");
ok($epm->serialise(0) !~ /$base64/, "serialise without files");

my $epm2 = $dataset->make_dataobj({
	version => '4.2.2',
});
ok($epm->version gt $epm2->version, "version gt");
$epm2->set_value( "version", "4.2.4" );
ok($epm->version lt $epm2->version, "version lt");

ok(1);

__DATA__
aGVsbG8sIHdvcmxkCg==
