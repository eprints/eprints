
$c->{set_document_defaults} = sub 
{
	my( $data, $handle, $eprint ) = @_;

	$data->{language} = $handle->get_langid();
	$data->{security} = "public";
};
