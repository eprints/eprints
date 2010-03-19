
# org_uri
$c->{rdf}->{org_uri} = sub {
	my( $eprint, $org_name ) = @_;

	return if( !$org_name );

	my $raw_id = "eprintsrdf/$org_name";
	utf8::encode( $raw_id ); # md5 takes bytes, not characters

	return "epid:x-org/".md5_hex( $raw_id );
};
