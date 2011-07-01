
push @{$c->{fields}->{user}},

{
	name => 'name',
	type => 'name',
	render_order => 'gf',
},

{
	name => 'dept',
	type => 'text',
},

{
	name => 'org',
	type => 'text',
},

{
	name => 'address',
	type => 'longtext',
	input_rows => 5,
},

{
	name => 'country',
	type => 'text',
},

{
	name => 'hideemail',
	input_style => 'radio',
	type => 'boolean',
},

{
	name => 'url',
	type => 'url',
},
; 
