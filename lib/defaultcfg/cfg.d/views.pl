
# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
        {
                id => "year",
                menus => [
			{
				fields => [ "date;res=year" ],
				reverse_order => 1,
                		allow_null => 1,
				new_column_at => [10,10],
			}
		],
                order => "creators_name/title",
		variations => [
			"creators_name;first_letter",
			"type",
			"DEFAULT" ],
        },
        {
                id => "subjects",
                menus => [
			{
				fields => [ "subjects" ],
                		hideempty => 1,
			}
		],
                order => "creators_name/title",
                include => 1,
		variations => [
			"creators_name;first_letter",
			"type",
		],
        },
        {
                id => "divisions",
                menus => [
			{
				fields => [ "divisions" ],
                		hideempty => 1,
			},
			{
				fields => [ "date;res=year" ],
				reverse_order => 1,
                		allow_null => 1,
                		hideempty => 1,
			},
		],
                order => "creators_name/title",
                include => 1,
		variations => [
			"creators_name;first_letter",
			"type",
			"DEFAULT",
		],
        },
        {
		id => "creators",
		allow_null => 0,
		hideempty => 1,
		menus => [
			{
				fields => [ "creators_name" ],
				new_column_at => [1, 1],
				mode => "sections",
				open_first_section => 1,
				group_range_function => "EPrints::Update::Views::cluster_ranges_30",
				grouping_function => "EPrints::Update::Views::group_by_a_to_z",
			},
		],
		order => "-date/title",
		variations => [
			"type",
			"DEFAULT",
		],
        },
];

# examples of some other useful views you might want to add
#
# Browse by the ID's of creators & editors (CV Pages). Useful to import the 
# .include part into your main website or their homepage, rather than access
# directly via the eprints website.
#        {
#                id => "person",
#                menus => [
#			{
#				fields => [ "creators_id","editors_id" ],
#                		allow_null => 0,
#			}
#		],
#                order => "-date/title",
#                noindex => 1,
#                nolink => 1,
#                nocount => 0,
#                include => 1,
#        },

# Browse by the names of creators (less reliable than Id's), section the menu 
# by the first 3 characters of the surname, and if there are more than 30 
# names, split the menu up into sub-pages of around 30.
# Show the list of names in 3 columns.
#
#
#	{ 
#		id => "people", 
#		menus => [ 
#			{ 
#				fields => ["creators_name","editors_name"], 
#				allow_null => 0,
#				grouping_function => "EPrints::Update::Views::group_by_3_characters",
#				group_range_function => "EPrints::Update::Views::cluster_ranges_30",
#				mode => "sections",
#				open_first_section => 1,
#				new_column_at => [0,0],
#			} 
#		],
#		order=>"title",
#	},


# Browse by the type of eprint (poster, report etc).
#{ id=>"type", menus=>[ { fields=>"type" } ], order=>"-date" }




