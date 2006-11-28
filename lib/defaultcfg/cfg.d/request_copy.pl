# The 'Request a copy' feature allows any user to request a copy of a 
# non-OA document by email. This function determines who to send the 
# request to. If, for a given eprint, the function returns undef, 
# the 'Request a copy' button(s) will not be shown.
#
# Tip: if the returned email address is a registered eprints user,
# requests for restricted documents can be handled within EPrints.
$c->{email_for_doc_request} = sub 
{
	my ( $session, $eprint ) = @_;

	# Uncomment the line below to turn off this feature
	#return undef;

	if ($eprint->is_set("contact_email")) {
		return $eprint->get_value("contact_email");
	}

	# Uncomment the line below to fall back to the email
	# address of the person who deposited this eprint - beware
	# that this may not always be the author!
	#my $user = $eprint->get_user;
	#if( defined $user && $user->is_set("email")) {
	#	return $user->get_value("email");
	#}

	# Uncomment the line below to fall back to the email
	# address of the archive administrator - think carefully!
	#return $session->get_repository->get_conf("adminemail");

	# Other alternatives:
	# - the email address of an individual who will deal with
	# document requests - beware there may be lots of requests!
	# - the email address of the first author

	return undef;
}
