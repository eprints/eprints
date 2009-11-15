
# event_uri
$c->{rdf}->{event_uri} = sub {
	my( $eprint ) = @_;

	my $ev_title = $eprint->get_value( "event_title" );
	return if( !defined $ev_title  );

	my $ev_dates = $eprint->get_value( "event_dates" ) || "";
	my $ev_location = $eprint->get_value( "event_location" ) || "";
	my $raw_id = "eprintsrdf/$ev_title/$ev_location/$ev_dates";

	return "epx:event/".md5_hex( $raw_id );
};
