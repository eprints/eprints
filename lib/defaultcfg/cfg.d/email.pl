
$c->{adminemail} = 'cjg@ecs.soton.ac.uk';

# If you want to override the way eprints sends email, you can
# set the send_email config option to be a function to use 
# instead.
#
# The function will have to take the following paramaters.
# $repository, $langid, $name, $address, $subject, $body, $sig, $replyto, $replytoname
# repository   string   utf8   utf8      utf8      DOM    DOM   string    utf8
#

# $c->{send_email} = \&EPrints::Email::send_mail_via_sendmail;
# $c->{send_email} = \&some_function;

# Uses the smtp_server specified in SystemSettings
$c->{send_email} = \&EPrints::Email::send_mail_via_smtp;

# If you want to import legacy data which is excempt from the normal
# validation methods, then uncomment this function and make it return
# true for eprints which are not to be validated.
# $c->{skip_validation} = sub { 
#	my( $eprint ) = @_;
#
#	return 0;
#};


# The 'Request a copy' feature allows any user to request a copy of a 
# non-OA document by email. This function determines who to send the 
# request to. If, for a given eprint, the function returns undef, the 
# 'Request a copy' button will not be shown for that eprint.
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

	return undef;
}
