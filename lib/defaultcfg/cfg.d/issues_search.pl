
$c->{issues_search} =
{
	search_fields => [
		{ meta_fields => [ "item_issues_type" ] },
		{ meta_fields => [ "item_issues_timestamp" ] },
		{ meta_fields => [ "userid.username" ] },
		{ meta_fields => [ "eprint_status" ], default=>'archive' },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "type" ] },
	],
	preamble_phrase => "search/issues:preamble",
	title_phrase => "search/issues:title",
	citation => "issue",
	page_size => 100,
	staff => 1,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"bydatestamp"	 => "-datestamp",
		"bydatestampoldest" => "datestamp",
		"byfirstseen" => "item_issues",
		"bynissues" => "-item_issues_count",
	},
	default_order => "byfirstseen",
	show_zero_results => 0,
};

