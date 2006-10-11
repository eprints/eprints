
######################################################################

=item $xhtml = render_fileinfo( $session, $field, $value )

This is a custom render method for the fileinfo field. It splits
up the information in the "fileinfo" field and renders icons which
link directly to the documents.

It is used to include file icons in a citation.

The fileinfo field is updated using the "L<set_eprint_automatic_fields|ArchiveMetadataFieldsConfig/set_eprint_automatic_fields>" method in C<ArchiveMetadataFieldsConfig.pm>.

=cut

######################################################################

sub render_fileinfo
{
	my( $session, $field, $value ) = @_;

	my $f = $session->make_doc_fragment;
	foreach my $icon ( split /\|/ , $value )
	{
		my( $type, $url ) = split( /;/, $icon );
		$f->appendChild( _render_fileicon( $session, $type, $url ));
	}

	return $f;
}

sub _render_fileicon
{
	my( $session, $type, $url ) = @_;

	# If you want to do something clever like
	# map several types to one icon, then this
	# is the place to do it! 

	my $a = $session->render_link( $url );
	$a->appendChild( $session->make_element( 
		"img", 
		src=>$session->get_repository->get_conf("base_url")."/style/images/fileicons/$type.png",
		width=>48,
		height=>48,
		border=>0 ));
	return $a;
}



