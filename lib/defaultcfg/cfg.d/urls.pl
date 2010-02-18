######################################################################
#
# URLS
#
#  These probably don't need changing.
#
######################################################################

# Site "home page" address
$c->{frontpage} = "$c->{base_url}/";

# The user area home page URL
$c->{userhome} = "$c->{perl_url}/users/home";

# If you don't want EPrints to respond to a specific URL add it to the
# exceptions here. Each exception is matched against the uri using regexp:
#  e.g. /myspecial/cgi
# Will match http://yourrepo/myspecial/cgi
#$c->{rewrite_exceptions} = [];

