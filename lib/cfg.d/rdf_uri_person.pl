
# creators_uri
$c->{rdf}->{person_uri} = sub {
	my( $eprint, $person ) = @_;

	my $repository = $eprint->repository;
	if( EPrints::Utils::is_set( $person->{id} ) )
	{
		# If you want to use hashed ID's to prevent people reverse engineering
		# them from the URI, uncomment the following line and edit SECRET to be 
		# something unique and unguessable. 
		#
		# return "epid:x-person/".md5_hex( utf8::encode( $person->{id}." SECRET" ));
		
		return "epid:x-person/".$person->{id};
	}
			
	my $name = $person->{name};	
	my $code = "eprintsrdf/".$eprint->get_id."/".($name->{family}||"")."/".($name->{given}||"");
	utf8::encode( $code ); # md5 takes bytes, not characters
	return "epid:x-person/".md5_hex( $code );
};

