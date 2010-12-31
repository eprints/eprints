
$c->{set_document_defaults} = sub 
{
	my( $data, $repository, $eprint ) = @_;

	$data->{language} = $repository->get_langid();
	$data->{security} = "public";
};
