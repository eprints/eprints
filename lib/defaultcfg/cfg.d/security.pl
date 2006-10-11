
# return one of:
# REQ 
# REQ_AND_USER [default]
# REQ_OR_USER
# for just USER security use REQ_AND_USER and make the REQ check always
# succeed.
# use REQ for request (location) based security, so it doesn't then
# ask for a username/password after passing the first part.
sub document_security_rule
{
	my( $security ) = @_;

	# these are example settings for domain based security
	# return( "REQ_AND_USER" ) if( $security eq "campus_and_validuser" );
	# return( "REQ_OR_USER" ) if( $security eq "campus_or_validuser" );
	# return( "REQ" ) if( $security eq "campus" );

	return( "REQ_AND_USER" );
}

# this method handles checking to see if a basic request is allowed to
# view a secured document. Usually this means checking the IP address 
# but other aspects of the request could also be used.
sub can_request_view_document
{
	my( $doc, $r ) = @_;

	#my $eprint = $doc->get_eprint();
	my $security = $doc->get_value( "security" );

	return( 1 ) if( $security eq "public" );

	# This _should_ work according to the mod_perl2 documentation,
	# but does not seem to. 
	#my $c = $r->connection();
	#my $remote_ip = $c->remote_ip();
	#my $remote_host = $c->remote_host();

	my $ip = $ENV{REMOTE_ADDR};

	# some examples of possible settings 

	# my( $oncampus ) = 0;
	# $oncampus = 1 if( $ip eq "152.78.69.157" );
	#
	# return( 1 ) if( $security eq "campus_and_validuser" && $oncampus );
	# return( 1 ) if( $security eq "campus_or_validuser" && $oncampus );
	# return( 1 ) if( $security eq "campus" && $oncampus );

	# return true if we are in a security model which does not care
	# about request-authentication.
	return( 1 ) if( $security eq "validuser" );
	return( 1 ) if( $security eq "staffonly" );


	$doc->get_session->get_repository->log( 
"unrecognized request security flag '$security' on document ".$doc->get_id );
	# return 0 if we don't recognise the security flag.
	return( 0 );
}

sub can_user_view_document
{
	my( $doc, $user ) = @_;

	my $eprint = $doc->get_eprint();
	my $security = $doc->get_value( "security" );

	# If the document belongs to an eprint which is in the
	# inbox or the editorial buffer then we treat the security
	# as staff only, whatever it's actual setting.
	if( $eprint->get_dataset()->id() ne "archive" )
	{
		$security = "staffonly";
	}

	# Add/remove types of security in metadata-types.xml

	# Trivial cases:
	return( 1 ) if( $security eq "public" );
	return( 1 ) if( $security eq "validuser" );

	# examples for location validation
	# return( 1 ) if( $security eq "validuser_and_campus" );
	# return( 1 ) if( $security eq "validuser_or_campus" );
	# if the mode is "campus" then this method will never be called 
	# as we set the rule to "REQ" (above).
	
	if( $security eq "staffonly" )
	{
		# If you want to finer tune this, you could create
		# new privs and use them.

		# people with priv editor can read this document...
		if( $user->has_priv( "editor" ) )
		{
			return 1;
		}

		# ...as can the user who deposited it...
		if( $user->get_value( "userid" ) == $eprint->get_value( "userid" ) )
		{
			return 1;
		}

		# ...but nobody else can
		return 0;
		
	}

	$doc->get_session->get_repository->log( 
"unrecognized user security flag '$security' on document ".$doc->get_id );
	# Unknown security type, be paranoid and deny permission.
	return( 0 );
}



