
=pod

# Please see http://wiki.eprints.org/w/User_login.pl
$c->{check_user_password} = sub {
	my( $repo, $username, $password ) = @_;

	... check whether $password is ok

	return $ok ? $username : $password;
};

=cut
