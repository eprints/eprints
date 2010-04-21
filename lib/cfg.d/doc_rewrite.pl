# handle relation-based document redirects
$c->add_trigger( EP_TRIGGER_DOC_REWRITE, sub {
	my( %args ) = @_;

	my( $request, $doc, $relations, $filename ) = @args{qw( request doc relations filename )};

	foreach my $r (@$relations)
	{
		my $relation = EPrints::Utils::make_relation( $r );
		$doc = $doc->get_related_objects( $relation )->[0];
		return 404 if !defined $doc;
		$filename = $doc->get_main;
	}

	$request->pnotes( document => $doc );
	$request->pnotes( filename => $filename );
}, priority => 99 );

# log full-text requests
$c->add_trigger( EP_TRIGGER_DOC_REWRITE, sub {
	my( %args ) = @_;

	my( $request, $relations ) = @args{qw( request relations )};

	if( !@$relations )
	{
		$request->push_handlers( PerlCleanupHandler => \&EPrints::Apache::LogHandler::document );
	}
}, priority => 100 );
