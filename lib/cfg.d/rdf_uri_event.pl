
# event_uri
$c->{rdf}->{event_uri} = sub {
	my( $eprint ) = @_;

	return if( !$eprint->dataset->has_field( "event_title" ) );

	my $ev_title = $eprint->get_value( "event_title" );
	return if( !defined $ev_title  );

	my $ev_dates = "";
	if( $eprint->dataset->has_field( "event_dates" ) )
	{
		$ev_dates = $eprint->get_value( "event_dates" ) || "";
	}

	my $ev_location = "";
	if( $eprint->dataset->has_field( "event_location" ) )
	{
		$ev_location = $eprint->get_value( "event_location" ) || "";
	}

	my $raw_id = "eprintsrdf/$ev_title/$ev_location/$ev_dates";
	utf8::encode( $raw_id ); # md5 takes bytes, not characters

	return "epid:event/ext-".md5_hex( $raw_id );
};
