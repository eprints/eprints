
$c->{set_user_defaults} = sub
{
	my( $data, $session ) = @_;

	$data->{hideemail} = "TRUE";

	# Default columns shown in Items and Editorial Review screens
	$data->{items_fields} = [ "title", "lastmod", "type", "eprint_status" ];
	$data->{review_fields} = [ "title", "status_changed", "type", "userid" ];
};
