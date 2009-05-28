# platform eprints is running on
if( $^O eq "MSWin32" )
{
	# not supported by trunk yet
}
else
{
	$c->{platform} = 'unix';
}
