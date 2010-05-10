# handle relation-based document redirects
$c->add_trigger( EP_TRIGGER_DOC_URL_REWRITE, sub {
	my( %args ) = @_;

	my( $request, $doc, $relations, $filename ) = @args{qw( request document relations filename )};

	foreach my $r (@$relations)
	{
		my $relation = EPrints::Utils::make_relation( $r );
		$doc = $doc->get_related_objects( $relation )->[0];
		if( !defined $doc )
		{
			$request->status( 404 );
			return EP_TRIGGER_DONE;
		}
		$filename = $doc->get_main;
	}

	$request->pnotes( dataobj => $doc );
	$request->pnotes( filename => $filename );
}, priority => 100 );
