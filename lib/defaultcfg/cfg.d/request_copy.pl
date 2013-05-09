# The 'Request a copy' feature allows any user to request a copy of a 
# non-OA document by email. This function determines who to send the 
# request to. If, for a given eprint, the function returns undef, 
# the 'Request a copy' button(s) will not be shown.
#
# Tip: if the returned email address is a registered eprints user,
# requests for restricted documents can be handled within EPrints.
$c->{email_for_doc_request} = sub 
{
	my ( $repository, $eprint ) = @_;

	# Uncomment the line below to turn off this feature
	#return undef;

	if( $eprint->is_set("contact_email") ) 
	{
		return $eprint->value("contact_email");
	}

	# Uncomment the lines below to fall back to the email
	# address of the person who deposited this eprint - beware
	# that this may not always be the author!
	#my $user = $eprint->get_user;
	#if( defined $user && $user->is_set( "email" ) )
	#{
	#	return $user->value( "email" );
	#}

	# Uncomment the line below to fall back to the email
	# address of the archive administrator - think carefully!
	#return $repository->config( "adminemail" );

	# Uncomment the lines below to fall back to a different
	# email address according on the divisions with which
	# the eprint is associated
	#foreach my $division ( @{ $eprint->value( "divisions" ) } )
	#{
	#	if( $division eq "sch_law" )
	#	{
	#		# email address of individual/team within the
	#		# department who will deal with requests
	#		return "enquiries\@law.yourrepository.org";
	#	}
	#	if( $division eq "sch_phy" )
	#	{
	#		# author email address (assumes "id" part of
	#		# creators field used for author email)
	#		if( $eprint->is_set( "creators" ) )
	#		{
	#			my $creators = $eprint->value( "creators" );
	#			my $contact = $creators->[1]; # first author
	#			#my $contact = $creators->[-1]; # last author
	#			return $contact->{id} if defined $contact->{id} && $contact->{id} ne "";
	#		}
	#	}
	#	# ...
	#}

	# 'Request a copy' not available for this eprint
	return undef; 
};

# The expiry for a document request (in days)
# $c->{expiry_for_doc_request} = 7;
