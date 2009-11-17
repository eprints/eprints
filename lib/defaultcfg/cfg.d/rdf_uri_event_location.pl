
# event location uri
$c->{rdf}->{event_location_uri} = sub {
	my( $eprint ) = @_;

	return if( !$eprint->dataset->has_field( "event_location" ) );

	my $ev_location = $eprint->get_value( "event_location" );
	return if( !EPrints::Utils::is_set( $ev_location ) );

	return "epx:location/".md5_hex( $ev_location );
};
	


