#!/usr/bin/perl -w -I /opt/eprints/perl_lib

#cjg ??? Write datestamps?

#cjg need to somehow keep track of comments. Maybe tag them onto next
#phrase?

use EPrints::DOM;
EPrints::DOM::setTagCompression( \&tag_compression );

my $BASELANG = "en";

my $langid = $ARGV[0];
if( !defined $langid )
{
	print "\nUsage:\n$0 <langcode>\n\n";
	exit 1;
}
if( $langid eq $BASELANG )
{
	print "\nlangid can't be $BASELANG\n\n";
	exit 1;
}
print "Language: $langid\n";

##

my $type;
foreach $type ( "archive","system" )
{
	print "Doing: $type file\n";

	my( $b_info, $b_n ) = load_latest( $type, $BASELANG );
	my( $f_info, $f_n ) = load_latest( $type, $langid );
	my( $b1_info ) = load_n( $type, $BASELANG, $f_n );
	
	if( $b_n == $f_n )
	{
		print "Both $BASELANG and $langid are on version $b_n\n";
		next;
	}
	my $tfile = $type."-".$langid."-".$b_n;
	print "Writing file: $tfile\n";
	
	my $doc = new EPrints::DOM::Document;
	my $doctype = $doc->createDocumentType( "phrases", "entities-".$langid.".dtd" );
	$doc->setDoctype( $doctype );
	my $xmldecl = $doc->createXMLDecl( "1.0", "UTF-8", "yes" );
	$doc->setXMLDecl( $xmldecl );
	my $phrases = $doc->createElement( "phrases" );
	$doc->appendChild( $phrases );
	$phrases->appendChild( $doc->createTextNode( "\n\n" ) );
	foreach( sort keys %{$b_info} )
	{
		my $node = $doc->createElement( "phrase" );
		$node->setAttribute( "ref", $_ );
		my $f;
		if( !defined $f_info->{$_} )
		{
			$node->setAttribute( "note", "UNTRANSLATED" );
			$f = $b_info->{$_};
		}
		else
		{
			$f = $f_info->{$_};
			my $note = $f_info->{$_}->getAttribute( "note" );
			my $n1 = $b_info->{$_};
			my $n2 = $b1_info->{$_};
			$n1->setAttribute( "note", undef );
			$n2->setAttribute( "note", undef );
			if( defined $note && $note ne "" )
			{
				$node->setAttribute( "note", $note );
			}
			elsif( $n1->toString ne $n2->toString )
			{
				$node->setAttribute( "note", "CHANGED" );
			}
		
		}
		foreach( $f->getChildNodes )
		{
			$f->setOwnerDocument( $doc );
			$node->appendChild( $f->removeChild( $_ ) );
		}
		$phrases->appendChild( $doc->createTextNode( "    " ) );
		$phrases->appendChild( $node );
		$phrases->appendChild( $doc->createTextNode( "\n\n" ) );
	}
	
	$doc->printToFile( $tfile );
	print "Wrote file.\n";
}
	
#########################################################

sub load_latest
{
	my( $set, $langid ) = @_;

	my $max = 0;
	opendir( PHRASES, "." ) || die "Can't open phrase dir";
	while( my $file = readdir(PHRASES) )
	{
		if( $file=~m/^$set-$langid-(\d+)$/ )
		{
			if( $1 > $max )	{ $max = $1; }
		}
	}
	close PHRASES;

	return( {}, 0 ) if( $max == 0 );

	return( load_n( $set, $langid, $max ), $max );
}

sub load_n
{
	my( $set, $langid, $n ) = @_;

	return {} if( $n == 0 );

	my $filename = "$set-$langid-$n";
	my $p = new EPrints::DOM::Parser( ErrorContext => 3 );
	my $doc = $p->parsefile( $filename );

	my $info = {};
	my $phrases = ($doc->getElementsByTagName( "phrases" ) )[0];
	my $phrase;
	foreach $phrase ( $phrases->getElementsByTagName( "phrase" )  )
	{
		my $id = $phrase->getAttribute( "ref" );
		$info->{$id} = $phrase;
	}
	return( $info );
}

sub tag_compression
{
	my( $tag, $elem ) = @_;

	return 1;
}

