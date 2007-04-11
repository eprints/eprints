
# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
        { 
		id => "subjects", 
		fields => "subjects", 
		order => "title", 
		hideempty => 1, 
	},
        { 
		id => "year", 
		allow_null => 1, 
		fields => "-date;res=year", 
		subheadings => "-date;res=month",
		#subheadings => "type", 
		order => "title", 
		heading_level => 2,
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


