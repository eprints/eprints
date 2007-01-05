package EPrints::Plugin::Import::PubMedXML;

use strict;

use EPrints::Plugin::Import::DefaultXML;

our @ISA = qw/ EPrints::Plugin::Import::DefaultXML /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "PubMed XML";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint', 'dataobj/eprint' ];

	return $self;
}

sub top_level_tag
{
	my( $plugin, $dataset ) = @_;

	return "PubmedArticleSet";
}

sub xml_to_epdata
{
	# $xml is the PubmedArticle element
	my( $plugin, $dataset, $xml ) = @_;

	my $epdata = {};

	my $citation = $xml->getElementsByTagName("MedlineCitation")->item(0);
	return unless defined $citation;

	my $article = $citation->getElementsByTagName("Article")->item(0);
	return unless defined $article;

	my $articletitle = $article->getElementsByTagName( "ArticleTitle" )->item(0);
	$epdata->{title} = $plugin->xml_to_text( $articletitle ) if defined $articletitle;

	my $journal = $article->getElementsByTagName( "Journal" )->item(0);
	if( defined $journal )
	{
		my $title = $journal->getElementsByTagName( "Title" )->item(0);
		$epdata->{publication} = $plugin->xml_to_text( $title ) if defined $title;

		my $issn = $journal->getElementsByTagName( "ISSN" )->item(0);
		$epdata->{issn} = $plugin->xml_to_text( $issn ) if defined $issn;

		my $journalissue = $journal->getElementsByTagName( "JournalIssue" )->item( 0 );
		if( defined $journalissue )
		{
			my $volume = $journalissue->getElementsByTagName( "Volume" )->item(0);
			$epdata->{volume} = $plugin->xml_to_text( $volume ) if defined $volume;
	
			my $issue = $journalissue->getElementsByTagName( "Issue" )->item(0);
			$epdata->{number} = $plugin->xml_to_text( $issue ) if defined $issue;

			my $pubdate = $journalissue->getElementsByTagName( "PubDate" )->item(0);
			if( defined $pubdate )
			{
				my $year = $pubdate->getElementsByTagName( "Year" )->item(0);
				$epdata->{date} = $plugin->xml_to_text( $year ) if defined $year;
			}
		}
	}

	my $pagination = $article->getElementsByTagName( "Pagination" )->item(0);
	if( defined $pagination )
	{
		my $medlinepgn = $pagination->getElementsByTagName( "MedlinePgn" )->item(0);
		if( defined $medlinepgn )
		{
			$epdata->{pagerange} = $plugin->xml_to_text( $medlinepgn );
		}
		else
		{
			my $startpage = $pagination->getElementsByTagName( "StartPage" )->item(0);
			if( defined $startpage )
			{
				$epdata->{pagerange} = $plugin->xml_to_text( $startpage );

				my $endpage = $pagination->getElementsByTagName( "EndPage" )->item(0);
				$epdata->{pagerange} .= "-" . $plugin->xml_to_text( $endpage ) if defined $endpage;
			}
		}
	}

	my $abstract = $article->getElementsByTagName( "Abstract" )->item(0);
	if( defined $abstract )
	{
		my $abstracttext = $abstract->getElementsByTagName( "AbstractText" )->item(0);
		$epdata->{abstract} = $plugin->xml_to_text( $abstracttext ) if defined $abstracttext;
	}

	my $authorlist = $article->getElementsByTagName( "AuthorList" )->item(0);
	if( defined $authorlist )
	{
		foreach my $author ( $authorlist->getElementsByTagName("Author") )
		{
			my $name = {};
			
			my $lastname = $author->getElementsByTagName( "LastName" )->item(0);
			$name->{family} = $plugin->xml_to_text( $lastname ) if defined $lastname;

			my $forename = $author->getElementsByTagName( "ForeName" )->item(0);
			$name->{given} = $plugin->xml_to_text( $forename ) if defined $forename;

			push @{ $epdata->{creators_name} }, $name;
		}
	}


	unless( defined $epdata->{publication} )
	{
		# Alternative way of getting (abbrev.) journal title
		my $medlinejournalinfo = $citation->getElementsByTagName( "MedlineJournalInfo" )->item(0);
		if( defined $medlinejournalinfo )
		{
			my $medlineta = $medlinejournalinfo->getElementsByTagName( "MedlineTA" )->item(0);
			$epdata->{publication} = $plugin->xml_to_text( $medlineta ) if defined $medlineta;
		}
	}

	# NLMCommon DTD has "Book" entity, but PubMed seems to
	# only contain articles
	# http://www.ncbi.nlm.nih.gov/entrez/query/DTD/nlmcommon_070101.dtd
	$epdata->{type} = "article";

	return $epdata;

}

1;
