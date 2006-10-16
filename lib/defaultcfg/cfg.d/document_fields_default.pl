
$c->{set_document_defaults} = sub 
{
	my( $data, $session, $eprint ) = @_;

	$data->{language} = $session->get_langid();
	$data->{security} = "public";
};
