
# creators_uri
$c->{rdf}->{publication_uri} = sub {
	my( $eprint ) = @_;

	my $repository = $eprint->repository;
	if( $eprint->dataset->has_field( "issn" ) && $eprint->is_set( "issn" ) )
	{
		my $issn = $eprint->get_value( "issn" );
		$issn =~ s/[^0-9X]//g;
		
		return "epid:publication/ext-$issn";
	}

	return if( !$eprint->is_set( "publication" ) );
			
	my $code = "eprintsrdf/".$eprint->get_value( "publication" );
	utf8::encode( $code ); # md5 takes bytes, not characters
	return "epid:publication/ext-".md5_hex( $code );
};

