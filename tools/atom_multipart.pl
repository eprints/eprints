#!/usr/bin/perl

=head1 SYNOPSIS

	cat test.bin | ./tools/atom_multipart.pl > atom_multipart.txt

	# find the boundary in atom_multipart.txt then do

	cat atom_multipart.txt | \
	POST \
	-C username:password \
	-c 'multipart/related; type="application/atom+xml"; boundary=$BOUNDARY$' \
	http://myrepo.org/id/contents

=cut

use strict;
use warnings;

use Getopt::Long;
use HTTP::Message;
use XML::LibXML;
use Encode;
use Pod::Usage;

my $content_type = 'application/octet-stream';
my $filename = 'main.bin';
my $header = 0;

GetOptions(
	'content-type=s' => \$content_type,
	'filename=s' => \$filename,
	'header' => \$header,
);

if( $filename =~ /[^\w\.]/ )
{
	$filename = Encode::encode_utf8( $filename );
	$filename =~ s/([^A-Za-z0-9\.])/sprintf("=%02x",ord($1))/eg;
	$filename = "\"=?utf-8?q?$filename?=\"";
}

my $cid = 'content_id_123';

my $doc = XML::LibXML::Document->new( '1.0', 'utf-8' );
my $entry = $doc->createElement( 'entry' );
$entry->setAttribute( xmlns => "http://www.w3.org/2005/Atom" );
$doc->setDocumentElement( $entry );

$entry->appendChild( $doc->createElement( 'title' ))
	->appendText( 'Atom Multipart Test Message Title' );
$entry->appendChild( $doc->createElement( 'id' ))
	->appendText( 'urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a' );
$entry->appendChild( $doc->createElement( 'author' ))
	->appendText( `whoami` );
(my $xsummary = $entry->appendChild( $doc->createElement( 'summary' )))
	->appendText( 'Atom Multipart Test Message Summary' );
$xsummary->setAttribute( type => 'text' );

my $xcontent = $entry->appendChild( $doc->createElement( 'content' ) );
$xcontent->setAttribute( src => "cid:$cid" );
$xcontent->setAttribute( type => $content_type );

my $mess = HTTP::Message->new(
	HTTP::Headers->new(
		MIME_Version => '1.0',
	),
	"Media Post"
);

$mess->add_part(
	HTTP::Message->new(
		HTTP::Headers->new(
			MIME_Version => '1.0',
			Content_Type => 'application/atom+xml; type=entry',
			Content_Disposition => 'attachment;name=atom',
		),
		$entry->toString( 1 )
	),
);

{
local $/;
my $part = HTTP::Message->new(
	HTTP::Headers->new(
		MIME_Version => '1.0',
		Content_Type => $content_type,
		Content_ID => $cid,
		Content_Disposition => "attachment;name=payload;filename=$filename",
	),
	<STDIN>
);
$part->encode( 'base64' );
${$part->content_ref} =~ s/\r?\n$//;
$part->headers->header( Content_Transfer_Encoding => ($part->headers->remove_header( 'Content-Encoding' ))[0] );
$mess->add_part( $part );
}

my $ct = $mess->headers->header( 'Content-Type' );
$ct =~ s#multipart/mixed#multipart/related#;
$mess->headers->header( Content_Type => "$ct; type=\"application/atom+xml\"" );

my $content = $mess->as_string;
if( !$header )
{
	$content =~ s/^.*?\n\r?\n//s; # strip headers
	$content =~ s/^.*?\n\r?\n//s; # strip first boundary
}
print $content;
