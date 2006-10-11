
# Browse views. allow_null indicates that no value set is 
# a valid result. 
# Multiple fields may be specified for one view, but avoid
# subject or allowing null in this case.
$c->{browse_views} = [
        { 
		id => "year", 
		allow_null => 1, 
		fields => "-date_effective;res=year", 
		subheadings => "type", 
		order => "-date_effective/title", 
		heading_level => 2,
	},
        { 
		id => "subjects", 
		fields => "subjects", 
		order => "-date_effective/title", 
		hideempty => 1, 
	}
];

# examples of some other useful views you might want to add
#
# Browse by the ID's of creators & editors (CV Pages)
# { id=>"people", allow_null=>0, fields=>"creators.id/editors.id", order=>"title/creators", noindex=>1, nolink=>1, nohtml=>1, include=>1, citation=>"title_only", nocount=>1 }
#
# Browse by the names of creators (less reliable than Id's)
#{ id=>"people", allow_null=>0, fields=>"creators/editors", order=>"title/creators",  include=>1 }
#
# Browse by the type of eprint (poster, report etc).
#{ id=>"type",  fields=>"type", order=>"-date_effective" }


