
# this method handles checking to see if a basic request is allowed to
# view a secured document. 

# Valid return values are
# "ALLOW" - allow the rquest to view the document
# "DENY"  - deny the request to view the document
# "USER"  - allow the request if the current user is allowed to view
#            the document. Ask for login if nobody is logged in.

$c->{can_request_view_document} = sub
{
	my( $doc, $r ) = @_;

	#my $eprint = $doc->get_eprint();
	my $security = $doc->value( "security" );

	my $eprint = $doc->get_eprint();
	my $status = $eprint->value( "eprint_status" );
	if( $security eq "public" && $status eq "archive" )
	{
		return( "ALLOW" );
	}

        my $code = EPrints::Apache::AnApache::cookie( $r, "eprints_doc_request" );
        if( EPrints::Utils::is_set( $code ) )
        {
                my $request = EPrints::DataObj::Request->new_from_code( $doc->get_session, $code );

                if( defined $request )
                {
                        my $docid = $doc->get_id;
                        my $target_docid = $request->get_value( "docid" );
                        if( "$docid" eq "$target_docid" )
                        {
                                return( "ALLOW" ) unless( $request->has_expired() );
                        }
                }
        }	

	my $ip = $r->connection()->remote_ip();

	# Example of how to allow an override for certain basic auth type usernames/passwords.
	# This is useful if you want the site to be read by a crawler, for example.
	# You may wish to wrap it all in a if( $ip eq "xxx" ) for added security.
	#
	# my( $res, $passwd_sent ) = $r->get_basic_auth_pw;
	# my( $user_sent ) = $r->user;
	# if( defined $user_sent )
	# {
	#	if( $user_sent eq "foo" && $passwd_sent eq "bar" )
	#	{
	#		return "ALLOW";
	#	}
	#	# return a 403.
	#	$r->note_basic_auth_failure;
	#	return "DENY";
	# }


	# some examples of possible settings 

	# my( $oncampus ) = 0;
	# $oncampus = 1 if( $ip eq "152.78.69.157" );
	# return( "USER" ) if( $security eq "campus_and_validuser" && $oncampus );
	# return( "ALLOW" ) if( $security eq "campus_or_validuser" && $oncampus );
	# return( "ALLOW" ) if( $security eq "campus" && $oncampus );
	# 
	# return( "DENY" ) if( $ip eq "101.34.34.1" );

	return( "USER" );
};

# Return "ALLOW" if the given user can view the given document,
# otherwise return "DENY".
$c->{can_user_view_document} = sub
{
	my( $doc, $user ) = @_;

	my $eprint = $doc->get_eprint();
	my $security = $doc->value( "security" );

	# If the document belongs to an eprint which is in the
	# inbox or the editorial buffer then we treat the security
	# as staff only, whatever it's actual setting.
	if( $eprint->dataset()->id() ne "archive" )
	{
		$security = "staffonly";
	}

	# Add/remove types of security in metadata-types.xml

	# Trivial cases:
	return( "ALLOW" ) if( $security eq "public" );
	return( "DENY" ) if( $user->get_type eq "minuser" ); 
	return( "ALLOW" ) if( $security eq "validuser" );

	# examples for location validation
	# return( "ALLOW" ) if( $security eq "validuser_and_campus" );
	# return( "ALLOW" ) if( $security eq "validuser_or_campus" );
	# if the mode is "campus" then this method will never be called.
	
	if( $security eq "staffonly" )
	{
		# If you want to finer tune this, you could create
		# new privs and use them.

		# people with priv editor can read this document...
		if( $user->has_role( "editor" ) )
		{
			return "ALLOW";
		}

		if( $user->has_role( "admin" ) )
		{
			return "ALLOW";
		}

		# ...as can the user who deposited it...
		if( $eprint->has_owner( $user ) )
		{
			return "ALLOW";
		}

		# ...but nobody else can
		return "DENY";
		
	}

	$doc->repository->log( 
"unrecognized user security flag '$security' on document ".$doc->get_id );
	# Unknown security type, be paranoid and deny permission.
	return( "DENY" );
};



