
# Override default username/password check
#$c->{check_user_password} = sub {
#	my( $session, $username, $password ) = @_;
#
#	my $user = EPrints::DataObj::User::user_with_username( $session, $username );
#	return 0 unless $user;
#
#	my $user_type = $user->get_type;
#	if( $user_type eq "user" || $user_type eq "editor" || $user_type eq "admin" )
#	{
#		# use default check
#		return EPrints::Apache::Login::valid_login( $session, $username, $password );
#	}
#
#	# check other kinds of user..
#}

