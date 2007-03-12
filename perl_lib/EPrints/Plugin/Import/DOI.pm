package EPrints::Plugin::Import::DOI;

use strict;

use EPrints::Plugin::Import::TextFile;

our @ISA = qw/ EPrints::Plugin::Import::TextFile /;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "DOI (via CrossRef)";
	$self->{visible} = "all";
	$self->{produce} = [ 'list/eprint' ];

	return $self;
}

sub input_fh
{
	my( $plugin, %opts ) = @_;

	my @ids;

	my $fh = $opts{fh};
	while( my $doi = <$fh> )
	{
		chomp $doi;

		my %params = (
			noredirect => "true",
			id => $doi,
		);

		my @cgi_params;
		foreach my $key (keys %params)
		{
        		push @cgi_params, $key . '=' . url_encode($params{$key});
		}
		my $url = "http://www.crossref.org/openurl?".join ('&', @cgi_params);

		$url =~ s/(['\\])/\\$1/g;

		my $cmd = "wget -O - '$url' 2>/dev/null";
		my $crossref_xml = `$cmd`;
	
		my $dom_doc = EPrints::XML::parse_xml_string( $crossref_xml );

		my $dom_top = $dom_doc->getDocumentElement;

		my $dom_query_result = ($dom_top->getElementsByTagName( "query_result" ))[0];
		my $dom_body = ($dom_query_result->getElementsByTagName( "body" ))[0];
		my $dom_query = ($dom_body->getElementsByTagName( "query" ))[0];

		my $data = { doi => $doi };
		foreach my $node ( $dom_query->getChildNodes )
		{
			next if( !EPrints::XML::is_dom( $node, "Element" ) );
			my $name = $node->tagName;
			my $value = EPrints::XML::to_string( EPrints::XML::contents_of( $node ) );
			if( $node->hasAttribute( "type" ) )
			{
				$name .= ".".$node->getAttribute( "type" );
			}
			$data->{$name} = $value;
		}

		my $epdata = $plugin->convert_input( $data );
		next unless( defined $epdata );

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids );
}

sub convert_input
{
	my( $plugin, $data ) = @_;

	my $epdata = {};

	if( defined $data->{author} )
	{
		$epdata->{creators} = [ 
			{ 
				name=>{ family=>$data->{author} }, 
			} 
		];
	}

	if( defined $data->{year} )
	{
		$epdata->{date} = $data->{year};
	}

	if( defined $data->{"issn.electronic"} )
	{
		$epdata->{issn} = $data->{"issn.electronic"};
	}
	if( defined $data->{"issn.print"} )
	{
		$epdata->{issn} = $data->{"issn.print"};
	}
	if( defined $data->{"doi"} )
	{
		$epdata->{id_number} = $data->{"doi"};
		my $doi = $data->{"doi"};
		$doi =~ s/^\s*doi:\s*//gi;
		$epdata->{official_url} = "http://dx.doi.org/$doi";
	}
	if( defined $data->{"volume_title"} )
	{
		$epdata->{book_title} = $data->{"volume_title"};
	}


	if( defined $data->{"journal_title"} )
	{
		$epdata->{publication} = $data->{"journal_title"};
	}
	if( defined $data->{"article_title"} )
	{
		$epdata->{title} = $data->{"article_title"};
	}


	if( defined $data->{"series_title"} )
	{
		# not sure how to map this!
		# $epdata->{???} = $data->{"series_title"};
	}


	if( defined $data->{"isbn"} )
	{
		$epdata->{isbn} = $data->{"isbn"};
	}
	if( defined $data->{"volume"} )
	{
		$epdata->{volume} = $data->{"volume"};
	}
	if( defined $data->{"issue"} )
	{
		$epdata->{number} = $data->{"issue"};
	}

	if( defined $data->{"first_page"} )
	{
		$epdata->{pagerange} = $data->{"first_page"};
	}

	if( defined $data->{"doi.conference_paper"} )
	{
		$epdata->{type} = "conference_item";
	}
	if( defined $data->{"doi.journal_article"} )
	{
		$epdata->{type} = "article";
	}

	return $epdata;
}

sub url_encode
{
        my ($str) = @_;
        $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
        return $str;
}

;
