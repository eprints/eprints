
=pod

# Please see http://wiki.eprints.org/w/User_login.pl
$c->{check_user_password} = sub {
	my( $repo, $username, $password ) = @_;

	... check whether $password is ok

	return $ok ? $username : undef;
};

=cut

# Maximum time (in seconds) before a user must log in again
# $c->{user_session_timeout} = undef; 

# Time (in seconds) to allow between user actions before logging them out
# $c->{user_inactivity_timeout} = 86400 * 7;

# Set the cookie expiry time
# $c->{user_cookie_timeout} = undef; # e.g. "+3d" for 3 days
