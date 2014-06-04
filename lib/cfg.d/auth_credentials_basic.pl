
$c->add_trigger( EP_TRIGGER_REQUEST_AUTH_CREDENTIALS, sub {
        my %params = @_;

        my $r = $params{request};
        my $rc = $params{return_code};
	my $repo = $params{repository};
	my $realm = $params{realm};

	$repo->debug_log( "auth", "AuthBasic..." );

        my $authorisation = $r->headers_in->{'Authorization'} || '';

	if( !EPrints::Utils::is_set( $authorisation ) )
	{
		$repo->debug_log( "auth", "AuthBasic: nothing to do" );
		return EP_TRIGGER_OK;
	}

        my( $username, $password );
        if( $authorisation =~ s/^Basic\s+// )
        {
                $authorisation = MIME::Base64::decode_base64( $authorisation );
                ($username, $password) = split /:/, $authorisation, 2;
        }
	else
	{
		# not a Basic auth
		$repo->debug_log( "auth", "AuthBasic: credentials found but failed base64 decoding" );
		return EP_TRIGGER_OK;
	}

	if( defined $username )
	{
		$repo->debug_log( "auth", "AuthBasic: %s logged-in", $username );

		if( $repo->login( $username, $password ) )
		{
			$$rc = EPrints::Apache::OK;
			return EP_TRIGGER_DONE;
		}
	}
	
	$repo->debug_log( "auth", "AuthBasic: nothing to do" );

	return EP_TRIGGER_OK;

}, priority => 50 );

