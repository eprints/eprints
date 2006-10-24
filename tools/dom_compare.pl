#!/usr/bin/perl

use strict;
use warnings;

use XML::DOM;
use XML::LibXML;
use XML::GDOME;

{
package LibXMLDoc;

use vars qw( @ISA );
@ISA = qw( XML::LibXML::Document );

sub appendChild
{
	shift->SUPER::setDocumentElement(@_);
}

1;
}

my( $doc );

# DOM
print "\n--XML::DOM--\n\n";

$doc = XML::DOM::Document->new;
$doc->appendChild($doc->createElement('foo'));
print $doc->toString;
print $doc->getDocumentElement->toString, "\n";
print $doc->cloneNode(1)->toString;

# LibXML
print "\n--XML::LibXML--\n\n";

$doc = XML::LibXML::Document->new;
$doc = bless $doc, 'LibXMLDoc';
$doc->appendChild($doc->createElement('foo'));
print $doc->toString;
print $doc->getDocumentElement->toString, "\n";
print $doc->cloneNode(1)->toString;

# GDOME
print "\n--XML::GDOME--\n\n";

$doc = XML::GDOME->createDocument( undef, "namespace", undef );
$doc->removeChild( $doc->getFirstChild );
$doc->appendChild($doc->createElement('foo'));
print $doc->toString;
print $doc->getDocumentElement->toString, "\n";
print $doc->cloneNode(1)->toString;

