
######################################################################
#
#  Search configuration
#
#   Before the repository goes public, ensure that these are correct and work OK.
#
#   To specify a search field that will search >1 metadata field, enter
#   all of the fields to be searched separated by slashes "/" as a single
#   entry. e.g.  "title/abstract/keywords".
#
#   When specifying ordering, separate the fields with a "/", and specify
#   proceed the fieldname with a dash "-" for reverse sorting.
#
######################################################################




$c->{search}->{simple} = 
{
	search_fields => [
		{
			id => "q",
			meta_fields => [
				$EPrints::Utils::FULLTEXT,
				"title",
				"abstract",
				"creators_name",
				"date" 
			]
		},
	],
	preamble_phrase => "cgi/search:preamble",
	title_phrase => "cgi/search:simple_search",
	citation => "result",
	page_size => 20,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date"
	},
	default_order => "byyear",
};
		

$c->{search}->{advanced} = 
{
	search_fields => [
		{ meta_fields => [ $EPrints::Utils::FULLTEXT ] },
		{ meta_fields => [ "title" ] },
		{ meta_fields => [ "creators_name" ] },
		{ meta_fields => [ "abstract" ] },
		{ meta_fields => [ "date" ] },
		{ meta_fields => [ "keywords" ] },
		{ meta_fields => [ "subjects" ] },
		{ meta_fields => [ "type" ] },
		{ meta_fields => [ "department" ] },
		{ meta_fields => [ "editors_name" ] },
		{ meta_fields => [ "ispublished" ] },
		{ meta_fields => [ "refereed" ] },
		{ meta_fields => [ "publication" ] },
		{ meta_fields => [ "documents.format" ] },
	],
	preamble_phrase => "cgi/advsearch:preamble",
	title_phrase => "cgi/advsearch:adv_search",
	citation => "result",
	page_size => 20,
	order_methods => {
		"byyear" 	 => "-date/creators_name/title",
		"byyearoldest"	 => "date/creators_name/title",
		"byname"  	 => "creators_name/-date/title",
		"bytitle" 	 => "title/creators_name/-date"
	},
	default_order => "byyear",
};


$c->{search}->{user} = 
{
	search_fields => [
		{ meta_fields => [ "name", ] },
		{ meta_fields => [ "username", ] },
		{ meta_fields => [ "userid", ] },
		{ meta_fields => [ "dept","org" ] },
		{ meta_fields => [ "address","country", ] },
		{ meta_fields => [ "usertype", ] },
		{ meta_fields => [ "email" ] },
	],
	citation => "result",
	page_size => 20,
	order_methods => {
		"byname" 	 =>  "name/joined",
		"byjoin"	 =>  "joined/name",
		"byrevjoin"  	 =>  "-joined/name",
		"bytype" 	 =>  "usertype/name",
	},
	default_order => "byname",
};

# If set to true, this option causes name searches to match the
# starts of surnames. eg. if true then "smi" will match the name
# "Smith".
$c->{match_start_of_name} = 0;

# customise the citation used to give results on the latest page
# nb. This is the "last 7 days" page not the "latest_tool" page.
$c->{latest_citation} = "default";

# Fields used for limiting the scope of editors
$c->{editor_limit_fields} =
[
	"subjects",
	"type"
];



######################################################################
#
# Latest_tool Configuration
#
#  the latest_tool script is used to output the last "n" items 
#  accepted into the repository
#
######################################################################

$c->{latest_tool_modes} = {
	default => { citation => "result" }
};

# Example of a latest_tool mode. This makes a mode=articles option
# which only lists eprints who's type equals "article".
#	
#	articles => {
#		citation => undef,
#		filters => [
#			{ meta_fields => [ "type" ], value => "article" }
#		],
#		max => 20
#	}


