#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

if (-e "/etc/centos-release")
{ 
    plan skip_all => 'Known issue on centos 6.5+: https://github.com/eprints/eprints/issues/370 '
}
else
{
    plan tests => 27;
}
use EPrints;
use EPrints::Test;

use LWP::UserAgent;
use XML::LibXML;
use XML::LibXML::XPathContext;

package MyUserAgent;

@MyUserAgent::ISA = qw( LWP::UserAgent );

sub get_basic_credentials
{
	my( $self, $realm, $uri, $isproxy ) = @_;
	return $self->SUPER::get_basic_credentials( "*", $uri, $isproxy );
}

package main;

my $repo = EPrints::Test->repository;

my $base_url = URI->new( $repo->config( "base_url" ) );
my $secure_url = URI->new( 'https://' . $repo->config( "securehost" ) );
$secure_url->port( $repo->config( "secureport" ) );
$secure_url->path( $repo->config( "https_root" ) );

my $data = "Hello, World!";
my $atom_data = join '', <DATA>;

my $ua = MyUserAgent->new( ssl_opts => { verify_hostname => 0 } );
$ua->credentials( $base_url->host_port, "*", "admin", "admin" );
$ua->credentials( $secure_url->host_port, "*", "admin", "admin" );

my $xpc = XML::LibXML::XPathContext->new;
$xpc->registerNs("atom", "http://www.w3.org/2005/Atom");
$xpc->registerNs("app", "http://www.w3.org/2007/app");
$xpc->registerNs("html", "http://www.w3.org/1999/xhtml");

ok(1);

my $end_point;

# Retrieve the Sword endpoint via the repository's home page <link>
{
	eval {
		my $r = $ua->get( $base_url );
		die "Error retrieving $base_url: ".$r->status_line
			if !$r->is_success;

		# stop LibXML trying to retrieve the DOCTYPE
		my $html = $r->content;
		$html =~ s/^.*?(?=<html)/<?xml version='1.0'?>\n/s;

		my $doc = eval { XML::LibXML->load_xml( string => $html ) };
		die "Failed to parse $base_url: $@"
			if !defined $doc;

		my( $link ) = $xpc->findnodes( q{/html:html/html:head/html:link[@rel='Sword']}, $doc->documentElement );
		die "Home page does not contain Sword link" if !defined $link;


		$r = $ua->get( $link->getAttribute( "href" ) );
		$doc = eval { XML::LibXML->load_xml( string => $r->content ) };
		die "Failed to parse ".$link->getAttribute( "href" )." $@"
			if !defined $doc;

		my( $coll ) = $xpc->findnodes( q{/app:service/app:workspace/app:collection}, $doc->documentElement );
		$end_point = $coll->getAttribute( "href" );
		die "Service document does not contain a collection"
			if !defined $end_point;
	};
	BAIL_OUT( $@ ) if $@;
}

my $edit_link;

SKIP:
{
	my $r = $ua->get( $end_point );

	is($r->code, 200, "GET /id/contents");
	is((split /\s*;\s*/, $r->header("Content-Type"))[0], "application/atom+xml", "/id/contents is ATOM xml");

	my $doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "XML parsing failed: $@", 1 if !defined $doc;

	my( $link ) = $xpc->findnodes(
			q{/atom:feed/atom:entry/atom:link[@rel='edit']},
			$doc->documentElement
		);
	$edit_link = $link ? $link->getAttribute( "href" ) : undef;

	ok(defined $edit_link, "Feed contains Atom entry with edit link");
}

SKIP:
{
	skip "Missing edit-link", 2 if !defined $edit_link;
	my $r = $ua->request( HTTP::Request->new(
			GET => $edit_link,
			[
				Accept => "application/atom+xml;type=entry",
			]
		) );

	is($r->code, 200, "GET $edit_link");
	is((split /\s*;\s*/, $r->header("Content-Type"))[0], "application/atom+xml", "$edit_link is ATOM xml");
}

{
	my $r = $ua->request( HTTP::Request->new(
			POST => $end_point,
			[
				'Content-Type' => "text/plain",
				'Content-Disposition' => "attachment; filename=hello.txt",
			],
			$data
		) );

	is($r->code, 201, "POST /id/contents CREATED");

	$edit_link = $r->header("Location");

	ok(defined $edit_link, "Location header set");
}

my $edit_media_link;

SKIP:
{
	skip "Missing edit-link", 2 if !defined $edit_link;
	my $r = $ua->request( HTTP::Request->new(
			GET => $edit_link,
			[
				Accept => "application/atom+xml;type=entry",
			]
		) );

	is((split /\s*;\s*/, $r->header("Content-Type"))[0], "application/atom+xml", "$edit_link is ATOM xml");

	my $doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "XML parsing failed", 1 if !defined $doc;
	my( $link ) = $xpc->findnodes(
			q{/atom:entry/atom:link[@rel='edit-media']},
			$doc->documentElement
		);
	$edit_media_link = defined $link ? $link->getAttribute( "href" ) : undef;

	ok(defined $edit_media_link, "$edit_link contains media link");
}

SKIP:
{
	skip "Missing edit-media-link", 5, if !defined $edit_media_link;
	my $r = $ua->get( $edit_media_link );

	is($r->content, $data, "GET $edit_media_link");

	$r = $ua->request( HTTP::Request->new(
			GET => $edit_media_link,
			[
				Accept => "application/atom+xml;type=feed",
			]
		) );

	is((split /\s*;\s*/, $r->header("Content-Type"))[0], "application/atom+xml", "$edit_media_link list is ATOM xml");

	my $doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "XML parsing failed", 3 if !defined $doc;
	my( $link ) = $xpc->findnodes(
			q{/atom:feed/atom:entry/atom:content[@type='text/plain']},
			$doc->documentElement
		);

	ok(defined $link, "Data attached as text/plain");

	skip "No content link", 2 if !defined $link;

	$r = $ua->request( HTTP::Request->new(
			GET => $link->getAttribute( "src" ),
			[
				Accept => "application/atom+xml;type=feed",
			]
		) );

	$doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "XML parsing failed", 2 if !defined $doc;

	( $link ) = $xpc->findnodes(
			q{/atom:feed/atom:entry/atom:id},
			$doc->documentElement
		);

	skip "XML feed missing <atom:entry> for file", 2 if !defined $link;

	# "Hello, World!" => "Hello, xxxld!"
	$r = $ua->request( HTTP::Request->new(
			PUT => $link->textContent,
			[
				'Content-Range' => '7-10/13',
				'Content-Length' => 3,
			],
			"xxx"
		) );

	is($r->code, 204, "PUT Content-Range: ".$link->textContent);

	$r = $ua->get( $link->textContent );

	is($r->content, "Hello, xxxld!", "PUT Content-Range succeeded");
}

SKIP:
{
	skip "Missing edit-media-link", 3 if !defined $edit_media_link;
	my $r = $ua->request( HTTP::Request->new(
			POST => $edit_media_link,
			[
				'Content-Type' => "application/octet-stream",
			],
			$data
		) );

	is($r->code, 201, "Created second item");

	my $link = $r->header( "Location" );
	skip "Missing Location header", 2 if !defined $link;
	$r = $ua->get( $link );

	is($r->content, $data, "$link matches");

	$r = $ua->request( HTTP::Request->new(
			DELETE => $link,
		) );

	is($r->code, 204, "DELETE $link");
}

SKIP:
{
	skip "Missing edit-media-link", 2 if !defined $edit_media_link;
	$ua->request( HTTP::Request->new(
			POST => $edit_media_link,
			[
				'Content-Type' => "application/octet-stream",
			],
			$data
		) );
	my $r = $ua->request( HTTP::Request->new(
			PUT => $edit_media_link,
			[
				'Content-Type' => "text/plain",
			],
			$data
		) );

	is($r->code, 204, "PUT $edit_media_link");

	$r = $ua->request( HTTP::Request->new(
			GET => $edit_media_link,
			[
				Accept => "application/atom+xml;type=feed",
			]
		) );
	my $doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "GET Atom XML failed", 1 if !defined $doc; 
	my @entries = $xpc->findnodes("/atom:feed/atom:entry", $doc->documentElement);

	is(scalar(@entries), 1, "PUT replaces all contents");
}

SKIP:
{
	skip "Missing edit-link", 3 if !defined $edit_link;
	my $r = $ua->request( HTTP::Request->new(
			GET => $edit_link,
			[
				Accept => "application/atom+xml;type=entry",
			]
		) );
	my $doc = eval { XML::LibXML->load_xml( string => $r->content ) };
	skip "GET Atom XML $edit_link", 2 if !defined $doc;
	my( $category ) = $xpc->findnodes( q{/atom:entry/atom:category[@scheme='http://eprints.org/ep2/data/2.0/eprint/eprint_status']}, $doc->documentElement );

	ok(defined $category, "Contains eprint status");

	skip "Missing eprint status", 2 if !defined $category;
	$category->setAttribute( "term", "buffer" );
	$r = $ua->request( HTTP::Request->new(
			PUT => $edit_link,
			[
				'Content-Type' => "application/atom+xml;type=entry",
			],
			$doc->toString
		) );

	is($r->code, 204, "PUT $edit_link");

	$r = $ua->request( HTTP::Request->new(
			GET => $edit_link,
			[
				Accept => "application/atom+xml;type=entry",
			]
		) );
	eval {
		my $doc = XML::LibXML->load_xml( string => $r->content );
		my( $category ) = $xpc->findnodes( q{/atom:entry/atom:category[@scheme='http://eprints.org/ep2/data/2.0/eprint/eprint_status']}, $doc->documentElement );

		is($category->getAttribute( "term" ), "buffer", "Status changed");
	};

	ok(0, "Status changed") if $@;
}

SKIP:
{
	skip "Missing edit-link", 1 if !defined $edit_link;
	my $r = $ua->request( HTTP::Request->new(
			DELETE => $edit_link,
		) );
	is($r->code, 204, "DELETE $edit_link");
}

SKIP:
{
	skip "Missing edit-link", 2 if !defined $edit_link;
	my $href = $edit_link;
	my $eprintid = $repo->database->counter_next( "eprintid" ) + 10;
	$href =~ s/\d+$/$eprintid/;
	my $r = $ua->request( HTTP::Request->new(
			PUT => $href,
			[
				'Content-Type' => 'application/atom+xml; type=entry',
			],
			$atom_data
		) );
	is($r->code, 201, "PUT $href CREATED");
	my $href2 = $r->header( "Location" );
	ok(defined $href2 && $href2 =~ /\b$eprintid\b/, "PUT created [$href != $href2]");
	$r->request( HTTP::Request->new(
			DELETE => $href2
		) );
	ok($repo->database->counter_next( "eprintid" ) > $eprintid, "counter got moved on");
}

__DATA__
<?xml version="1.0" encoding="utf-8" ?>
<entry xmlns="http://www.w3.org/2005/Atom">
  <title>My New Title</title>
  <summary>This is demonstration data only.</summary>
  <id>http://yomiko.ecs.soton.ac.uk:8080/id/eprint/11278</id>
  <category term="article" label="article" scheme="http://yomiko.ecs.soton.ac.uk:8080/data/eprint/type/"/>
  <category term="inbox" label="inbox" scheme="http://eprints.org/ep2/data/2.0/eprint/eprint_status"/>
</entry>
