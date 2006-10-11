
sub set_document_defaults
{
	my( $data, $session, $eprint ) = @_;

	$data->{language} = $session->get_langid();
	$data->{security} = "public";
}

