
# This function allows you to override the default username/password
# authentication. For example, you could apply different authentication rules to 
# different types of user.
#
# Example: LDAP Authentication (Quick Start)
#
# Tip: use the test script to determine your LDAP parameters first!
# Tip: remove the set-password priviledge from users and editors in
# user_roles.pl. Also consider removing edit-own-record and 
# change-email.
#
#$c->{check_user_password} = sub {
#	my( $handle, $username, $password ) = @_;
#
#	my $user = EPrints::DataObj::User::user_with_username( $handle, $username );
#	return 0 unless $user;
#
#	my $user_type = $user->get_type;
#	if( $user_type eq "admin" )
#	{
#		# internal authentication for "admin" type
#		return $handle->get_database->valid_login( $username, $password );
#	}
#
#	# LDAP authentication for "user" and "editor" types
#
#	# LDAP hostname (and port if not the default)
#	my $ldap_host = "ldap.host.name";
#	#my $ldap_host = "ldap.host.name:1234";
#	#my $ldap_host = "ldaps://ldap.host.name"; # if server supports LDAPS
#
#	# Distinguished name for this user
#	# The distinguished name is a unique name for an LDAP entry.
#	# e.g. "cn=John Smith, ou=staff, dc=eprints, dc=org"
#	# You will need to derive this from the username or user metadata
#	my $ldap_dn = "cn=$username, ou=yourorg, dc=yourdomain";
#
#	use Net::LDAP; # IO::Socket::SSL also required
#
#	my $ldap = Net::LDAP->new ( $ldap_host, version => 3 );
#	unless( $ldap )
#	{
#		print STDERR "LDAP error: $@\n";
#		return 0;
#	}
#
#	# Start secure connection (not needed if using LDAPS)
#	my $ssl = $ldap->start_tls( sslversion => "sslv3" );
#	if( $ssl->code() )
#	{
#		print STDERR "LDAP SSL error: " . $ssl->error() . "\n";
#		return 0;
#	}
#
#	# Check password
#	my $mesg = $ldap->bind( $ldap_dn, password => $password );
#	if( $mesg->code() )
#	{
#		return 0;
#	}
#
#	return 1;
#}
# Advanced LDAP Configuration
#
# 1. It is also possible to define additional user types, each with a different
# authentication mechanism. For example, you could keep the default user, 
# editor and admin types and add ldapuser, ldapeditor and ldapadmin types with
# LDAP authentication - this would suit an arrangement where internal staff are 
# authenticated against the LDAP server but user accounts can still be granted 
# to external users.
#
# 2. Sometimes the distinguished name of the user is not computable from the 
# username. You may need to use values from the user metadata (e.g. name_given,
# name_family):
#
#	my $name = $user->get_value( "name" );
#	my $ldap_dn = $name->{family} . ", " . $name->{given} .", ou=yourorg, dc=yourdomain";
#
# or perform an LDAP lookup to determine it (more complicated):
#
#	my $base = "ou=yourorg, dc=yourdomain";
#	my $result = $ldap->search (
#		base    => "$base",
#		scope   => "sub",
#		filter  => "cn=$username",
#		attrs   =>  ['DN'],
#		sizelimit=>1
#	);
#
#	my $entr = $result->pop_entry;
#	unless( defined $entr )
#	{
#		return 0;
#	}
#	my $ldap_dn = $entr->dn
#
# Alternatively, you could store the distinguished name as part of the user 
# metadata when the user account is imported 
 

