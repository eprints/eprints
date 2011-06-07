
# If set to true, this option causes name searches to match the
# starts of surnames. eg. if true then "smi" will match the name
# "Smith".
$c->{match_start_of_name} = 0;

# customise the citation used to give results on the latest page
# nb. This is the "last 7 days" page not the "latest_tool" page.
$c->{latest_citation} = "default";

# This configuration file had got rather large, so has been split
# into the following other config. files:
#   user_review_scope.pl
#   latest_tool.pl
#   issues_search.pl
#   user_search.pl
#   eprint_search_advanced.pl
#   eprint_search_simple.pl

