use strict;
use Test::More tests => 9;

BEGIN { use_ok( "EPrints" ); }
BEGIN { use_ok( "EPrints::Test" ); }

my $session = EPrints::Test::get_test_session( 0 );
ok(defined $session, 'opened an EPrints::Session object (noisy, no_check_db)');

{
package MyHander;

sub new { bless {}, shift; }

sub message
{
	my( $self, $type, $xml ) = @_;

	my $mess = EPrints::XML::to_string( $xml );
	EPrints::XML::dispose( $xml );

	push @{$self->{$type}||=[]}, $mess;
}
}

my $doc = EPrints::XML::parse_xml_string( join "", <DATA> );
my( $eprint_xml ) = $doc->documentElement->getElementsByTagName( "eprint" );

my $handler = MyHander->new;
my $epdata = EPrints::DataObj::EPrint->xml_to_epdata( $session, $eprint_xml, Handler => $handler );

is( $epdata->{title}, "Fulvous Whistling Ducks and Man", "Parsed title" );
is( $epdata->{creators}->[0]->{name}->{family}, "Toda", "Parsed 1st creator" );

my %warnings = (
	bad_field => 0,
	bad_document => 0,
	bad_item => 0,
	bad_name_part => 0
	);
foreach my $warning (@{$handler->{warning}})
{
	while(my( $key, $value ) = each %warnings)
	{
		$warnings{$key} = 1 if $warning =~ /$key/;
	}
}

foreach my $test (sort keys %warnings)
{
	ok( $warnings{$test}, "Invalid XML element: $test" );
}

EPrints::XML::dispose( $doc );

$session->terminate;

__DATA__
<?xml version="1.0" encoding="utf-8" ?>
<eprints xmlns="http://eprints.org/ep2/data/2.0">
  <eprint id="http://yomiko.ecs.soton.ac.uk:8080/id/eprint/100" xmlns="http://eprints.org/ep2/data/2.0">
    <eprintid>100</eprintid>
    <rev_number>2</rev_number>
	<bad_field>asdasdasd</bad_field>
    <documents>
	  <bad_document></bad_document>
      <document id="http://yomiko.ecs.soton.ac.uk:8080/id/document/671">
        <docid>671</docid>
        <rev_number>3</rev_number>
        <files>
          <file id="http://yomiko.ecs.soton.ac.uk:8080/id/file/980">
            <fileid>980</fileid>
            <datasetid>document</datasetid>
            <objectid>671</objectid>
            <filename>indexcodes.txt</filename>
            <mime_type>text/plain</mime_type>
            <hash>a39762b923e9d4b815eabda0e344f53a</hash>
            <hash_type>MD5</hash_type>
            <filesize>103</filesize>
            <mtime>2009-06-09 08:15:24</mtime>
            <url>http://yomiko.ecs.soton.ac.uk:8080/100/3/indexcodes.txt</url>
            <copies>
              <item>
                <pluginid>Storage::Local</pluginid>
                <sourceid>indexcodes.txt</sourceid>
              </item>
            </copies>
          </file>
        </files>
        <eprintid>100</eprintid>
        <pos>3</pos>
        <placement>3</placement>
        <format>indexcodes</format>
        <formatdesc>Generate index codes conversion from application/pdf to indexcodes</formatdesc>
        <language>en</language>
        <security>public</security>
        <main>indexcodes.txt</main>
        <relation>
          <item>
            <type>http://eprints.org/relation/isVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/isVolatileVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/isIndexCodesVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
        </relation>
      </document>
      <document id="http://yomiko.ecs.soton.ac.uk:8080/id/document/231">
        <docid>231</docid>
        <rev_number>3</rev_number>
        <files>
          <file id="http://yomiko.ecs.soton.ac.uk:8080/id/file/361">
            <fileid>361</fileid>
            <datasetid>document</datasetid>
            <objectid>231</objectid>
            <filename>preview.jpg</filename>
            <mime_type>image/jpeg</mime_type>
            <hash>0f66da4ed2a17be8c3e9fea227bf8137</hash>
            <hash_type>MD5</hash_type>
            <filesize>9227</filesize>
            <mtime>2009-06-05 11:46:56</mtime>
            <url>http://yomiko.ecs.soton.ac.uk:8080/100/2/preview.jpg</url>
            <copies>
              <item>
                <pluginid>Storage::Local</pluginid>
                <sourceid>preview.jpg</sourceid>
              </item>
            </copies>
          </file>
        </files>
        <eprintid>100</eprintid>
        <pos>2</pos>
        <placement>2</placement>
        <format>image/jpeg</format>
        <formatdesc>Thumbnail Documents conversion from application/pdf to thumbnail_preview</formatdesc>
        <language>en</language>
        <security>public</security>
        <main>preview.jpg</main>
        <relation>
          <item>
            <type>http://eprints.org/relation/isVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/isVolatileVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/ispreviewThumbnailVersionOf</type>
            <uri>_internal:document.230</uri>
          </item>
        </relation>
      </document>
      <document id="http://yomiko.ecs.soton.ac.uk:8080/id/document/230">
        <docid>230</docid>
        <rev_number>3</rev_number>
        <files>
          <file id="http://yomiko.ecs.soton.ac.uk:8080/id/file/360">
            <fileid>360</fileid>
            <datasetid>document</datasetid>
            <objectid>230</objectid>
            <filename>paper.pdf</filename>
            <mime_type>application/pdf</mime_type>
            <hash>8628e41b6818f896a8e011d9ac31aae1</hash>
            <hash_type>MD5</hash_type>
            <filesize>12174</filesize>
            <mtime>2009-06-05 11:46:55</mtime>
            <url>http://yomiko.ecs.soton.ac.uk:8080/100/1/paper.pdf</url>
            <copies>
              <item>
                <pluginid>Storage::Local</pluginid>
                <sourceid>paper.pdf</sourceid>
              </item>
            </copies>
          </file>
        </files>
        <eprintid>100</eprintid>
        <pos>1</pos>
        <placement>1</placement>
        <format>application/pdf</format>
        <language>en</language>
        <security>public</security>
        <main>paper.pdf</main>
        <relation>
          <item>
            <type>http://eprints.org/relation/hasVolatileVersion</type>
            <uri>_internal:document.231</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/hasVersion</type>
            <uri>_internal:document.231</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/haspreviewThumbnailVersion</type>
            <uri>_internal:document.231</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/hasVolatileVersion</type>
            <uri>_internal:document.671</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/hasVersion</type>
            <uri>_internal:document.671</uri>
          </item>
          <item>
            <type>http://eprints.org/relation/hasIndexCodesVersion</type>
            <uri>_internal:document.671</uri>
          </item>
        </relation>
      </document>
    </documents>
    <eprint_status>archive</eprint_status>
    <userid>1</userid>
    <dir>disk0/00/00/01/00</dir>
    <datestamp>2009-06-05 11:46:55</datestamp>
    <lastmod>2009-06-05 11:46:55</lastmod>
    <status_changed>2009-06-05 11:46:55</status_changed>
    <type>conference_item</type>
    <metadata_visibility>show</metadata_visibility>
    <item_issues_count>0</item_issues_count>
    <creators>
	  <bad_item>asdasd</bad_item>
      <item>
        <name>
          <family>Toda</family>
          <given>Y.</given>
		  <bad_name_part>XXX</bad_name_part>
        </name>
        <id></id>
      </item>
      <item>
        <name>
          <family>Aφροδίτη</family>
          <given>O.</given>
        </name>
        <id></id>
      </item>
      <item>
        <name>
          <family>Ερμής</family>
          <given>C.</given>
        </name>
        <id></id>
      </item>
    </creators>
    <title>Fulvous Whistling Ducks and Man</title>
    <ispublished>pub</ispublished>
    <subjects>
      <item>CS</item>
      <item>GA</item>
      <item>ZA4050</item>
      <item>QH</item>
    </subjects>
    <full_text_status>public</full_text_status>
    <pres_type>paper</pres_type>
    <abstract>This is where the abstract of this record would appear. This is only demonstration data.</abstract>
    <date>2005</date>
    <event_title>Animal Data Conference</event_title>
    <event_location>London</event_location>
    <event_dates>23-25 November</event_dates>
  </eprint>
</eprints>
