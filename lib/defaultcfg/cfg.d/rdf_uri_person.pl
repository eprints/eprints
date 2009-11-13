
# creators_uri
$c->{rdf}->{person_uri} = sub {
	my( $eprint, $person ) = @_;

	my $repository = $eprint->get_session->get_repository;
	if( EPrints::Utils::is_set( $person->{id} ) )
	{
		return "epx:person/".$person->{id};
	}
			
	my $name = $person->{name};	
	my $code = "eprintsrdf/".$eprint->get_id."/".($name->{family}||"")."/".($name->{given}||"");

	return "epx:person/".md5_hex( $code );
};

