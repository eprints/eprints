
$c->{fields}->{user} = [

	{ name => "name", type => "name", render_order=>"gf" },

	{ name => "dept", type => "text" },

	{ name => "org", type => "text" },

	{ name => "address", type => "longtext", input_rows => 5 },

	{ name => "country", type => "text" },

	{ name => "hideemail", type => "boolean", input_style=>"radio" },

	{ name => "os", type => "set", input_rows => 1,
		options => [ "win", "unix", "vms", "mac", "other" ] },

	{ name => "url", type => "url" }

];

