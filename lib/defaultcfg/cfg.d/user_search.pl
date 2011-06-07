
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
	show_zero_results => 1,
};

