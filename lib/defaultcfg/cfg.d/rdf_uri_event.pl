
# event_uri
$c->{rdf}->{event_uri} = sub {
	my( $eprint ) = @_;

	my $ev_title = $eprint->get_value( "event_title" );
	my $ev_dates = $eprint->get_value( "event_dates" );
	my $ev_location = $eprint->get_value( "event_location" );
	my $raw_id;
	if( defined $ev_title && $ev_title ne "" )
	{
		$raw_id = "eprintsrdf/$ev_title/".($ev_location||"")."/".($ev_dates||"");
	}
	else
	{
		# If this eprint is a conference item but doesn't have an event title
		# then use eprint ID to unique it.
		$raw_id = "eprintsrdf/".$eprint->get_id."/event";
	}

	return "epx:event/".md5_hex( $raw_id );
};
