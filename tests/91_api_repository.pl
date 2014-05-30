#!/usr/bin/perl

use Test::More tests => 21;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();
my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );

is( $repo->id, $repoid, "\$repo->id" );

# Real tests below:

my $xml = $repo->xml;
isa_ok( $xml, "EPrints::XML", "Get an XML object from the repository" );

my $xhtml = $repo->xhtml;
isa_ok( $xhtml, "EPrints::XHTML", "Get an XHTML object from the repository" );

my $config_element = $repo->config( "host" );
ok( defined $config_element, "Get a config. element" );

my $config_element2 = $repo->config( "search", "simple" );
isa_ok( $config_element2, "HASH", "Get a search config. element" );

$repo->log( "Checking write to log goes OK" );
pass( "Write to log" );

my $dataset = $repo->dataset( "user" );
isa_ok( $dataset, "EPrints::DataSet", "Get dataset object from the repository" );

my $test_eprint = EPrints::Test::get_test_dataobj( $repo->dataset( "eprint" ) );
my $eprint = $repo->eprint( $test_eprint->id );
isa_ok( $eprint, "EPrints::DataObj::EPrint", "Repository->eprint( id )" );

my $test_user = EPrints::Test::get_test_dataobj( $repo->dataset( "user" ) );
my $user = $repo->user( $test_user->id );
isa_ok( $user, "EPrints::DataObj::User", "Repository->user( id )" );

my $username = $user->value( "username" );
my $user2 = $repo->user_by_username( $username );
isa_ok( $user2, "EPrints::DataObj::User", "Get a user object by username from the repository" );

my $email = $user->value( "email" );
my $user3 = $repo->user_by_email( $email );
isa_ok( $user3, "EPrints::DataObj::User", "Get a user object by email '$email' from the repository" );

# No test for:
#
# $user = $repo->current_user;
# $current_page_url = $repo->current_url; 
# $query = $repo->query;
# $string = $repo->query->param( "X" );
# $repo->redirect( $url );

SKIP: {
my $store = $repo->plugin( "Storage::LocalCompress" );
skip "Storage::LocalCompress requires PerlIO::gzip", 1 unless defined $store;

my $storage = $repo->get_storage;

my $doc = EPrints::Test::get_test_document( $repo );
my $file = $doc->get_stored_file( $doc->get_main );

$storage->delete_copy( $store, $file );

my( $path, $fn ) = $store->_filename( $file );

$storage->copy( $store, $file );

ok( -e "$path/$fn", "storage->copy()" );

$storage->delete_copy( $store, $file );
$file->commit;
}

my @field_tests = (
<<EOP => 1,
\$c->add_dataset_field( 'eprint', {
	name => "title",
	type => "longtext",
},
	reuse => 1,
);
EOP
<<EOP => 0,
\$c->add_dataset_field( 'eprint', {
	name => "title",
	type => "longtext",
});
EOP
<<EOP => 0,
\$c->add_dataset_field( 'eprint', {
	name => "title",
	type => "int",
	reuse => 1,
});
EOP
<<EOP => 1,
\$c->add_dataset_field( 'eprint', {
	name => "add_dataset_field",
	type => "text",
});
EOP
);

our $cfg_file = $repo->config( "config_path" )."/cfg.d/zz_91_api_repository.pl";
END
{
	unlink($cfg_file);
}

foreach my $i (grep { $_ % 2 == 0 } 0..$#field_tests)
{
	open(my $fh, ">", $cfg_file) or die "Error writing to $cfg_file: $!";
	print $fh $field_tests[$i];
	close($fh);

	my( $rc, $output ) = $repo->test_config;
	ok(
		($field_tests[$i+1] && $rc == 0) ||
		(!$field_tests[$i+1] && $rc != 0)
	, "add_dataset_field ".($i/2 + 1)." $rc\n$output" );
}

ok( $repo->can( "remote_ip" ), "Client-IP wrapper in place" );
