
######################################################################
#
# Dynamic Template
#
# If you use a dynamic template then this function is called every
# time a page is served to generate dynamic parts of it.
# 
# The dynamic template feature may be disabled to reduce server load.
#
# When enabling/disabling it, run 
# generate_apacheconf
# generate_static
# generate_views
# generate_abstracts
#
######################################################################

$c->{dynamic_template}->{enable} = 1;

# This method is called every time ANY html page in the system is
# requested so don't do anything that's very intensive.
# The best way to do things like that are to do them once every five
# miuntes and cache them to a file.

$c->{dynamic_template}->{function} = sub {
	my( $session, $parts ) = @_;

	my $user = $session->current_user;
	if( defined $user )
	{
		$parts->{login_status} = $session->html_phrase( 
			"dynamic:logged_in", 
			user => $user->render_description,
			tools => $session->render_toolbar );
	}
	else
	{
		$parts->{login_status} = $session->html_phrase( 
			"dynamic:not_logged_in" );
	}
};

