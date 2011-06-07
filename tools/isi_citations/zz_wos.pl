
# this field is used to store the ISI citation data
push @{$c->{fields}->{eprint}},
{
	'name' => 'wos',
	'type' => 'compound',
	'volatile' => 1,
	'fields' => [
		{
			'sub_name' => 'cluster',
			'type' => 'text',
		},
		{
			'sub_name' => 'impact',
			'type' => 'int',
		},
		{
			'sub_name' => 'datestamp',
			'type' => 'time',
		},
	],
};

# filters to apply to eprints before searching for them in ISI
# (remove to look for all)
$c->{wos}->{filters} = [
	{ meta_fields => [qw( refereed )], value => "TRUE" },
	{ meta_fields => [qw( type )], merge => "ANY", value => "article conference_item" },
];

# return a ISI search query string in UTF-8 based on $eprint
# return undef if we can't build a query
$c->{wos}->{build_query} = sub
{
	my( $eprint ) = @_;

	return unless $eprint->is_set( "creators_name" );
	return unless $eprint->is_set( "title" );

	my $name = $eprint->get_value( "creators_name" )->[0];
	my $family = $name->{family};
	utf8::decode($family);
	my $given = $name->{given};
	utf8::decode($given);
	if( defined $given && length $given )
	{
		$name = sprintf("%s %s*", $family, substr($given,0,1));
	}
	else
	{
		$name = $family;
	}

	my $title = $eprint->get_value( "title" );
	utf8::decode($title);
	$title =~ s/[^\p{Letter}\p{Number}]+/ /g;

	my $query = "AU = ($name) and TI = ($title)";

	return $query;
};
