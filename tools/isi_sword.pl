#!/usr/bin/perl -w

=head1 NAME

B<isi_citations.pl> - ISI Web of Science citations tool

=head1 SYNOPSIS

B<isi_citations.pl> [B<options>] I<query>

=head1 OPTIONS

=over 8

=item B<--verbose>

Be more verbose.

=back

=cut

use strict;

use constant {
	NS_SWORD    => 'http://purl.org/net/sword/',
	NS_APP      => 'http://www.w3.org/2007/app',
	NS_DCTERMS  => 'http://purl.org/dc/terms/',
	NS_ATOM     => 'http://www.w3.org/2005/Atom',
	NS_EPDATA   => 'http://eprints.org/ep2/data/2.0',
};

our $VERSION = "1.00";

use XML::LibXML;
use XML::LibXML::XPathContext;
use SOAP::ISIWoK;
use Getopt::Long;
use Pod::Usage;
use LWP::UserAgent;

my $opt_help = 0;
my $opt_verbose = 0;
my $opt_quiet = 0;
my $opt_collection;
my $opt_email;
my $opt_endpoint;
my $opt_username;
my $opt_password;
my $opt_max = 10;

GetOptions(
	"help|?" => \$opt_help,
	"verbose+" => \$opt_verbose,
	"quiet" => \$opt_quiet,
	"collection=s" => \$opt_collection,
	"email=s" => \$opt_email,
	"endpoint=s" => \$opt_endpoint,
	"username=s" => \$opt_username,
	"password=s" => \$opt_password,
	"max=s" => \$opt_max,
) or pod2usage( 2 );

pod2usage( 1 ) if $opt_help;
pod2usage( 0 ) if @ARGV != 1;

pod2usage( "Requires endpoint" ) if !$opt_endpoint;

my $noise = $opt_quiet ? 0 : $opt_verbose+1;

if( $noise > 2 )
{
	eval "use LWP::Debug";
	LWP::Debug::level( '+' ); # full tracing
}

my( $query ) = @ARGV;

my $doc = XML::LibXML::Document->new;

my $ua = LWP::UserAgent->new;

$ua->agent( "ISI-to-Sword/$VERSION" );
$ua->from( $opt_email ) if $opt_email;

my $collections = collections();

if( !keys %$collections )
{
	die "No supported collection endpoints\n";
}

if( !$opt_collection )
{
	print STDERR "Requires collection argument, choose from the following:\n";
	foreach my $href (sort keys %$collections)
	{
		my $col = substr($href,length($opt_endpoint));
		print STDERR "$col\t".$collections->{$href}->{title}."\n";
	}
	die "\n";
}

my $eprints = query( $query );

submit( $opt_endpoint . $opt_collection, $eprints );

#print $eprints->toString( 1 );

sub query
{
	my( $query ) = @_;

	my $wok = SOAP::ISIWoK->new;

	my $xml = $wok->search( $query, max => $opt_max );

	my @records;

	my $eprints = $doc->createElement( "eprints" );
	$eprints->setAttribute( xmlns => NS_EPDATA );

	foreach my $rec ($xml->getElementsByTagName( "REC" ))
	{
		my $epdata = xml_to_epdata( undef, undef, $rec );
		next if !scalar keys %$epdata;
		$eprints->appendChild( epdata_to_xml( $epdata ) );
	}

	return $eprints;
}

sub xml_to_epdata
{
	my( $self, $dataset, $rec ) = @_;

	my $epdata = {};

	my $node;

	( $node ) = $rec->findnodes( "item/item_title" );
	$epdata->{title} = $node->textContent if $node;

	if( !$node )
	{
		die "Expected to find item_title in: ".$rec->toString( 1 );
	}

	( $node ) = $rec->findnodes( "item/source_title" );
	if( $node )
	{
		$epdata->{publication} = $node->textContent;
		$epdata->{status} = "published";
	}

	foreach my $node ($rec->findnodes( "item/article_nos/article_no" ))
	{
		my $id = $node->textContent;
		if( $id =~ s/^DOI\s+// )
		{
			$epdata->{id_number} = $id;
		}
	}

	( $node ) = $rec->findnodes( "item/bib_pages" );
	$epdata->{pagerange} = $node->textContent if $node;

	( $node ) = $rec->findnodes( "item/bib_issue" );
	if( $node )
	{
		$epdata->{date} = $node->getAttribute( "year" ) if $node->hasAttribute( "year" );
		$epdata->{volume} = $node->getAttribute( "vol" ) if $node->hasAttribute( "vol" );
	}

	# 
	$epdata->{type} = "article";
	( $node ) = $rec->findnodes( "item/doctype" );
	if( $node )
	{
	}

	foreach my $node ($rec->findnodes( "item/authors/*" ))
	{
		if( $node->nodeName eq "fullauthorname" )
		{
			next if !$epdata->{creators};
			my( $family ) = $node->getElementsByTagName( "AuLastName" );
			my( $given ) = $node->getElementsByTagName( "AuFirstName" );
			$family = $family->textContent if $family;
			$given = $given->textContent if $given;
			$epdata->{creators}->[$#{$epdata->{creators}}]->{name} = {
				family => trim($family),
				given => trim($given),
			};
		}
		else
		{
			my $name = $node->textContent;
			my( $family, $given ) = split /,/, $name, 2;
			push @{$epdata->{creators}}, {
				name => { family => trim($family), given => trim($given) },
			};
		}
	}

	foreach my $node ($rec->findnodes( "item/keywords/*" ))
	{
		push @{$epdata->{keywords}}, $node->textContent;
	}
	$epdata->{keywords} = join ", ", @{$epdata->{keywords}} if $epdata->{keywords};

	( $node ) = $rec->findnodes( "item/abstract" );
	$epdata->{abstract} = $node->textContent if $node;

	# stuff the complete data in notes for debug
	$epdata->{note} = $rec->toString( 1 );

	return $epdata;
}

sub epdata_to_xml
{
	my( $epdata ) = @_;

	my $xml = $doc->createElement( "eprint" );

	while(my( $key, $value ) = each %$epdata)
	{
		$xml->appendChild( _epdata_to_xml( $doc, $key, $value ) );
	}

	return $xml;
}

sub _epdata_to_xml
{
	my( $doc, $key, $epdata ) = @_;

	my $xml = $doc->createElement( $key );

	if( ref($epdata) eq "HASH" )
	{
		while(my( $key, $value ) = each %$epdata)
		{
			$xml->appendChild( _epdata_to_xml( $doc, $key, $value ) );
		}
	}
	elsif( ref($epdata) eq "ARRAY" )
	{
		foreach my $value (@$epdata)
		{
			$xml->appendChild( _epdata_to_xml( $doc, "item", $value ) );
		}
	}
	else
	{
		$xml->appendChild( $doc->createTextNode( $epdata ) );
	}

	return $xml;
}

sub trim
{
	my( $str ) = @_;

	return $str if !defined $str;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

sub collections
{
	my $req = HTTP::Request->new( GET => $opt_endpoint . "/servicedocument" );
	$req->authorization_basic( $opt_username, $opt_password ) if $opt_username;

	my $res = $ua->request( $req );

	if( !$res->is_success )
	{
		Carp::croak "Error getting servicedocument: " . $res->status_line;
	}

	my $servicedoc = XML::LibXML->new->parse_string( $res->content );
	my $xpc = XML::LibXML::XPathContext->new( $servicedoc->documentElement );

	$xpc->registerNs( 'app', NS_APP );
	$xpc->registerNs( 'dcterms', NS_DCTERMS );
	$xpc->registerNs( 'atom', NS_ATOM );
	$xpc->registerNs( 'sword', NS_SWORD );
	
	my $node;

	( $node ) = $xpc->findnodes( "sword:version" );
	my $version = $node->textContent;
	Carp::croak "Only supports version 1.3, got '$version'" if $version ne "1.3";

	my %collections;

	foreach my $collection ($xpc->findnodes( "app:workspace/app:collection" ))
	{
		next if !$collection->hasAttribute( "href" );
		my $c = { href => $collection->getAttribute( "href" ), accepts => [] };
		$collections{$c->{href}} = $c;
		my $ok = 0;
		foreach my $prop ($collection->childNodes)
		{
			next if !$prop->isa( "XML::LibXML::Element" );
			my $name = $prop->localName;
			my $value = trim( $prop->textContent );
			if( $prop->namespaceURI eq NS_SWORD )
			{
				if( $name eq "acceptPackaging" )
				{
					$ok = 1 if $value eq NS_EPDATA;
					push @{$c->{accepts}}, { prefer => $prop->getAttribute( "q" ), namespaceURI => $value };
				}
				elsif( $name eq "collectionPolicy" )
				{
					$c->{policy} = $value;
				}
				elsif( $name eq "treatment" )
				{
					$c->{treatment} = $value;
				}
			}
			elsif( $prop->namespaceURI eq NS_ATOM )
			{
				if( $name eq "title" )
				{
					$c->{title} = $value;
				}
			}
		}
		if( !$ok )
		{
			delete $collections{$c->{href}};
			if( $noise > 0 )
			{
				print STDERR "Can't use collection $c->{href}: unsupported metadata types\n";
			}
		}
	}

	return \%collections;
}

sub submit
{
	my( $endpoint, $eprints ) = @_;

	foreach my $eprint ($eprints->getElementsByLocalName( "eprint" ) )
	{
		submit_eprint( $endpoint, $eprint );
	}
}

sub submit_eprint
{
	my( $endpoint, $eprint ) = @_;

	my $eprints = $doc->createElement( "eprints" );
	$eprints->setAttribute( xmlns => NS_EPDATA );

	$eprints->appendChild( $eprint->parentNode->removeChild( $eprint ) );

	my $req = HTTP::Request->new( POST => $endpoint );
	$req->authorization_basic( $opt_username, $opt_password ) if $opt_username;

	$req->header( 'X-Packaging' => NS_EPDATA );
	$req->content_type( 'text/xml' );

	$req->content( "<?xml version='1.0'?>\n" . $eprints->toString );

	my $res = $ua->request( $req );

	if( !$res->is_success )
	{
		die "Error posting: ".$res->status_line;
	}
}

1;
