
$c->{set_user_automatic_fields} = sub
{
	my( $user ) = @_;

	if( !$user->is_set( "frequency" ) )
	{
		$user->set_value( "frequency", "never" );
	}
};
