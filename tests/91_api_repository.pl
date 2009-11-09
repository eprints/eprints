#!/usr/bin/perl

use Test::More tests => 14;

use strict;
use warnings;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $repoid = EPrints::Test::get_test_id();
my $ep = EPrints->new();
isa_ok( $ep, "EPrints", "EPrints->new()" );
my $repo = $ep->repository( $repoid );
isa_ok( $repo, "EPrints::Repository", "Get a repository object ($repoid)" );

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

my $eprint = $repo->eprint( 23 );
isa_ok( $eprint, "EPrints::DataObj::EPrint", "Get an eprint object from the repository" );

my $user = $repo->user( 1 );
isa_ok( $user, "EPrints::DataObj::User", "Get a user object from the repository" );

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
