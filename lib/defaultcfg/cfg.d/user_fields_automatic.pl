
sub set_user_automatic_fields
{
	my( $user ) = @_;

	if( !$user->is_set( "frequency" ) )
	{
		$user->set_value( "frequency", "never" );
	}
}
