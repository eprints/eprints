
$c->{fields}->{eprint} = [

	{ 
		name        => "creators", 
		type        => "compound",  
		input_boxes => 4,
		multiple    => 1,
		fields=>[
			{ 
				sub_name         => "name", 
				type            => "name", 
				family_first    => 1, 
				hide_honourific => 1, 
				hide_lineage    => 1, 
			}, 
			{ 
				sub_name    => "id", 
				type       => "text", 
				input_cols => 20, 
				allow_null => 1, 
			},
		],
	},

	{
		name     => "corp_creators",
		type     => "text",
		multiple => 1,
	},
		

	{ name => "title", type => "longtext", multilang=>0, input_rows => 3 },

	{ name => "ispublished", type => "set", input_style=>"medium",
			options => [ "pub","inpress","submitted" , "unpub" ] },

	{ name => "subjects", type=>"subject", top=>"subjects", multiple => 1, 
		browse_link => "subjects",
		render_input=>"EPrints::Extras::subject_browser_input" },

	{ name => "full_text_status", type=>"set", input_style=>"medium",
			options => [ "public", "restricted", "none" ] },

	{ name => "monograph_type", type=>"set", input_style=>"medium",
			options => [ 
				"technical_report", 
				"project_report",
				"documentation",
				"manual",
				"working_paper",
				"discussion_paper",
				"other" ] },



	{ name => "pres_type", type=>"set", input_style=>"medium",
			options => [ 
				"paper", 
				"lecture", 
				"speech", 
				"poster", 
				"other" ] },

	{ name => "keywords", type => "longtext", input_rows => 2 },

	{ 
		name => "note", 
		type => "longtext", 
		input_rows => 3,
	},

	{ 
		name => "suggestions", 
		type => "longtext",
		render_value => "EPrints::Extras::render_highlighted_field",
	},

	{ 
		name => "abstract", 
		input_rows => 10,
		type => "longtext",
	},

	{ name => "date", type=>"date", min_resolution=>"year" },

	{ name => "date_type", type=>"set", options=>[qw/ published submitted completed /] },

	{ name => "series", type => "text" },

	{ name => "publication", type => "text" },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "publisher", type => "text" },

	{ name => "place_of_pub", type => "text" },

	{ name => "pagerange", type => "pagerange" },

	{ name => "pages", type => "int", maxlength => 6, sql_index => 0 },

	{ name => "event_title", type => "text" },

	{ name => "event_location", type => "text" },
	
	{ name => "event_dates", type => "text" },

	{ name => "event_type", type => "set", options=>[ "conference","workshop","other" ], input_style=>"medium", },

	{ name => "id_number", type => "text" },

	{ name => "patent_applicant", type => "text" },

	{ name => "institution", type => "text" },

	{ name => "department", type => "text" },

	{ name => "thesis_type", type => "set", options=>[ "masters", "phd", "other"], input_style=>"medium", },

	{ name => "refereed", type => "boolean", input_style=>"radio" },

	{ name => "isbn", type => "text" },

	{ name => "issn", type => "text" },

	{ name => "fileinfo", type => "longtext",
		render_value=>"render_fileinfo" },

	{ name => "book_title", type => "text" },
	
	{
		name => "editors", 
		type=>"compound",  
		input_boxes => 4,
		multiple=>1,
		fields=>[
			{ 
				sub_name => "name", 
				type => "name", 
				family_first => 1, 
				hide_honourific => 1, 
				hide_lineage => 1, 
			}, 
			{ 
				sub_name => "id", 
				type => "text", 
				input_cols => 20, 
				allow_null => 1, 
			},
		],
	},

	{ 
		name => "official_url", 
		type=>"url",  
	},

	{ 
		name => "related_url", 
		type=>"compound",  
		input_boxes => 1,
		input_ordered => 0,
		multiple=>1,
		fields=>[
			{ 
				sub_name => "url", 
				type => "url", 
				input_cols => 40,
			},
			{ 
				sub_name => "type", 
				type => "set", 
				options => [qw/ pub author org /],
			},
		],
	},

# nb. Can't call this field "references" because that's a MySQL keyword.
	{ name => "referencetext", type => "longtext", input_rows => 3 },

];

