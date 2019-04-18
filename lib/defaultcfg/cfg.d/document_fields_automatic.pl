$c->{set_document_automatic_fields} = sub {
	my( $doc ) = @_;
	#######
	#
	# Populate the media size values. TODO other media type
	#
	#######
	if(($doc->value("format") eq "image") && defined($doc->value("main"))){
	#	use Image::Size;
	#	my $file_local_path = $doc->local_path . "/" . $doc->value("main");
	#	my ($width, $height, $id) = imgsize( "$file_local_path" );
	#	$doc->set_value("media_width", $width);
	#	$doc->set_value("media_height", $height);
	}
};
