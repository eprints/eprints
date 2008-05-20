
# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
        {
                id => "year",
                allow_null => 1,
                fields => "-date;res=year",
                order => "creators_name/title",
                subheadings => "type",
		variations => [
			"creators_name;first_letter",
			"type",
			"DEFAULT" ],
        },
        {
                id => "subjects",
                allow_null => 0,
                fields => "subjects,-date;res=year",
                order => "creators_name/title",
                include => 1,
                hideempty => 1,
		variations => [
			"creators_name;first_letter",
			"type",
		],
        },
        {
                id => "divisions",
                allow_null => 0,
                fields => "divisions,-date;res=year",
                order => "creators_name/title",
                include => 1,
                hideempty => 1,
		variations => [
			"creators_name;first_letter",
			"type",
			"DEFAULT",
		],
        },
        {
                id => "person",
                allow_null => 0,
                fields => "creators_id/editors_id",
                order => "-date/title",
                noindex => 1,
                nolink => 1,
                nocount => 0,
                include => 1,
                subheadings => "type",
        },
];

# examples of some other useful views you might want to add
#
# Browse by the ID's of creators & editors (CV Pages)
# { id=>"people", allow_null=>0, fields=>"creators_id/editors_id", order=>"title", noindex=>1, nolink=>1, nohtml=>1, include=>1, citation=>"title_only", nocount=>1 }
#
# Browse by the names of creators (less reliable than Id's)
#{ id=>"people", allow_null=>0, fields=>"creators_name/editors_name", order=>"title",  include=>1 }
#
# Browse by the type of eprint (poster, report etc).
#{ id=>"type",  fields=>"type", order=>"-date" }


