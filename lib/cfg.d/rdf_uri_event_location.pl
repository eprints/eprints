
# event location uri
$c->{rdf}->{event_location_uri} = sub {
	my( $eprint ) = @_;

	return if( !$eprint->dataset->has_field( "event_location" ) );

	my $ev_location = $eprint->get_value( "event_location" );
	return if( !EPrints::Utils::is_set( $ev_location ) );

	utf8::encode( $ev_location ); # md5 takes bytes, not characters
	return "epid:x-location/".md5_hex( $ev_location );
};
	


