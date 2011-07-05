
push @{$c->{fields}->{eprint}},

{
	name => 'creators',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		}
	],
	input_boxes => 4,
},

{
	name => 'contributors',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'type',
			type => 'namedset',
			set_name => "contributor_type",
		},
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		},
	],
	input_boxes => 4,
},

{
	name => 'corp_creators',
	type => 'text',
	multiple => 1,
},

{
	name => 'title',
	type => 'longtext',
	input_rows => 3,
	make_single_value_orderkey => 'EPrints::Extras::english_title_orderkey',
},

{
	name => 'ispublished',
	type => 'set',
	options => [qw(
		pub
		inpress
		submitted
		unpub
	)],
	input_style => 'medium',
},

{
	name => 'subjects',
	type => 'subject',
	multiple => 1,
	top => 'subjects',
	browse_link => 'subjects',
},

{
	name => 'divisions',
	type => 'subject',
	multiple => 1,
	top => 'divisions',
	browse_link => 'divisions',
},

{
	name => 'full_text_status',
	type => 'set',
	options => [qw(
		public
		restricted
		none
	)],
	input_style => 'medium',
},

{
	name => 'monograph_type',
	type => 'set',
	options => [qw(
		technical_report
		project_report
		documentation
		manual
		working_paper
		discussion_paper
		other
	)],
	input_style => 'medium',
},

{
	name => 'pres_type',
	type => 'set',
	options => [qw(
		paper
		lecture
		speech
		poster
		keynote
		other
	)],
	input_style => 'medium',
},

{
	name => 'keywords',
	type => 'longtext',
	input_rows => 2,
},

{
	name => 'note',
	type => 'longtext',
	input_rows => 3,
},

{
	name => 'suggestions',
	type => 'longtext',
	render_value => 'EPrints::Extras::render_highlighted_field',
	export_as_xml => 0, 
},

{
	name => 'abstract',
	type => 'longtext',
	input_rows => 10,
},

{
	name => 'date',
	type => 'date',
	min_resolution => 'year',
},

{
	name => 'date_type',
	type => 'set',
	options => [qw(
		published
		submitted
		completed
	)],
	input_style => 'medium',
},

{
	name => 'series',
	type => 'text',
},

{
	name => 'publication',
	type => 'text',
},

{
	name => 'volume',
	type => 'text',
	maxlength => 6,
},

{
	name => 'number',
	type => 'text',
	maxlength => 6,
},

{
	name => 'publisher',
	type => 'text',
},

{
	name => 'place_of_pub',
	type => 'text',
},

{
	name => 'pagerange',
	type => 'pagerange',
},

{
	name => 'pages',
	type => 'int',
	maxlength => 6,
	sql_index => 0,
},

{
	name => 'event_title',
	type => 'text',
},

{
	name => 'event_location',
	type => 'text',
},

{
	name => 'event_dates',
	type => 'text',
},

{
	name => 'event_type',
	type => 'set',
	options => [qw(
		conference
		workshop
		other
	)],
	input_style => 'medium',
},

{
	name => 'id_number',
	type => 'text',
	render_value => 'EPrints::Extras::render_possible_doi',
},

{
	name => 'patent_applicant',
	type => 'text',
},

{
	name => 'institution',
	type => 'text',
},

{
	name => 'department',
	type => 'text',
},

{
	name => 'thesis_type',
	type => 'set',
	options => [qw(
		masters
		phd
		engd
		other
	)],
	input_style => 'medium',
},

{
	name => 'refereed',
	type => 'boolean',
	input_style => 'radio',
},

{
	name => 'isbn',
	type => 'text',
},

{
	name => 'issn',
	type => 'text',
},

{
	name => 'book_title',
	type => 'text',
},

{
	name => 'editors',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			hide_honourific => 1,
			type => 'name',
			hide_lineage => 1,
			family_first => 1,
			sub_name => 'name',
		},
		{
			input_cols => 20,
			allow_null => 1,
			type => 'text',
			sub_name => 'id',
		}
	],
	input_boxes => 4,
},

{
	name => 'official_url',
	type => 'url',
	render_value => 'EPrints::Extras::render_url_truncate_end',
},

{
	name => 'related_url',
	type => 'compound',
	multiple => 1,
	render_value => 'EPrints::Extras::render_related_url',
	fields => [
		{
			sub_name => 'url',
			type => 'url',
			input_cols => 40,
		},
		{
			sub_name => 'type',
			type => 'set',
			options => [qw(
				pub
				author
				org
			)],
		}
	],
	input_boxes => 1,
	input_ordered => 0,
},

{
	name => 'referencetext',
	type => 'longtext',
	input_rows => 15,
},

{
	name => 'funders',
	type => 'text',
	multiple => 1,
	input_boxes => 1,
},

{
	name => 'projects',
	type => 'text',
	multiple => 1,
	input_boxes => 1,
},

{
	name => 'output_media',
	type => 'text',
},

{
	name => 'exhibitors',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		}
	],
	input_boxes => 2,
},

{
	name => 'num_pieces',
	type => 'int',
},

{
	name => 'composition_type',
	type => 'text',
},

{
	name => 'producers',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		}
	],
	input_boxes => 1,
},

{
	name => 'conductors',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		}
	],
	input_boxes => 1,
},

{
	name => 'lyricists',
	type => 'compound',
	multiple => 1,
	fields => [
		{
			sub_name => 'name',
			type => 'name',
			hide_honourific => 1,
			hide_lineage => 1,
			family_first => 1,
		},
		{
			sub_name => 'id',
			type => 'text',
			input_cols => 20,
			allow_null => 1,
		}
	],
	input_boxes => 1,
},

{
	name => 'accompaniment',
	type => 'text',
	multiple => 1,
	input_boxes => 1,
},

{
	name => 'data_type',
	type => 'text',
},

{
	name => 'pedagogic_type',
	type => 'set',
	options => [qw(
		presentation
		activity
		case
		enquiry
		problem
		collaboration
		communication
	)],
},

{
	name => 'completion_time',
	type => 'text',
},

{
	name => 'task_purpose',
	type => 'longtext',
},

{
	name => 'skill_areas',
	type => 'text',
	multiple => 1,
	input_boxes => 1,
},

{
	name => 'copyright_holders',
	type => 'text',
	multiple => 1,
	input_boxes => 1,
},

{
	name => 'learning_level',
	type => 'text',
},

{
	name => 'gscholar',
	type => 'compound',
	volatile => 1,
	fields => [
		{ sub_name => 'impact', type => 'int', },
		{ sub_name => 'cluster', type => 'id', },
		{ sub_name => 'datestamp', type => 'time', },
	],
	sql_index => 0,
},
;
