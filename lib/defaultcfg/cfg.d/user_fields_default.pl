
$c->{set_user_defaults} = sub
{
	my( $data, $repository ) = @_;

	$data->{hideemail} = "TRUE";

	# Default columns shown in Items and Editorial Review screens
	$data->{items_fields} = [ "lastmod", "title", "type", "eprint_status" ];
	$data->{review_fields} = [ "status_changed", "title", "type", "userid" ];
};
