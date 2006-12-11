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
	my( $plugin, $dataset, $xml ) = @_;

	my $epdata = {};

	my $citation = $xml->getElementsByTagName("MedlineCitation")->item(0);
	return unless defined $citation;

	my $article = $citation->getElementsByTagName("Article")->item(0);
	return unless defined $article;

	my $title_node = $article->getElementsByTagName( "ArticleTitle" )->item(0);
	$epdata->{title} = $plugin->xml_to_text( $title_node ) if defined $title_node;

	my $journal = $article->getElementsByTagName( "Journal" )->item(0);
	if( defined $journal )
	{
		my $issn_node = $journal->getElementsByTagName( "ISSN" )->item(0);
		$epdata->{issn} = $plugin->xml_to_text( $issn_node ) if defined $issn_node;

		my $issue = $journal->getElementsByTagName( "JournalIssue" )->item( 0 );
		if( defined $issue )
		{
			my $volume_node = $issue->getElementsByTagName( "Volume" )->item(0);
			$epdata->{volume} = $plugin->xml_to_text( $volume_node ) if defined $volume_node;
	
			my $issue_node = $issue->getElementsByTagName( "Issue" )->item(0);
			$epdata->{number} = $plugin->xml_to_text( $issue_node ) if defined $issue_node;

			my $date = $issue->getElementsByTagName( "PubDate" )->item(0);
			if( defined $date )
			{
				my $year_node = $date->getElementsByTagName( "Year" )->item(0);
				$epdata->{date} = $plugin->xml_to_text( $year_node ) if defined $year_node;
			}
		}
	}

	my $pagination = $article->getElementsByTagName( "Pagination" )->item(0);
	if( defined $pagination )
	{
		my $page_node = $pagination->getElementsByTagName( "MedlinePgn" )->item(0);
		$epdata->{pagerange} = $plugin->xml_to_text( $page_node ) if defined $page_node;
	}

	my $abstract = $article->getElementsByTagName( "Abstract" )->item(0);
	if( defined $abstract )
	{
		my $abs_node = $abstract->getElementsByTagName( "AbstractText" )->item(0);
		$epdata->{abstract} = $plugin->xml_to_text( $abs_node ) if defined $abs_node;
	}

	my $authorlist = $article->getElementsByTagName( "AuthorList" )->item(0);
	if( defined $authorlist )
	{
		foreach my $author ( $authorlist->getElementsByTagName("Author") )
		{
			my $name = {};
			
			my $lastname_node = $author->getElementsByTagName( "LastName" )->item(0);
			$name->{family} = $plugin->xml_to_text( $lastname_node ) if defined $lastname_node;

			my $firstname_node = $author->getElementsByTagName( "ForeName" )->item(0);
			$name->{given} = $plugin->xml_to_text( $firstname_node ) if defined $firstname_node;

			push @{ $epdata->{creators_name} }, $name;
		}
	}

	my $medlinejournalinfo = $citation->getElementsByTagName( "MedlineJournalInfo" )->item(0);
	if( defined $medlinejournalinfo )
	{
		my $medlineta_node = $medlinejournalinfo->getElementsByTagName( "MedlineTA" )->item(0);
		$epdata->{publication} = $plugin->xml_to_text( $medlineta_node ) if defined $medlineta_node;
	}

	return $epdata;

}

1;
