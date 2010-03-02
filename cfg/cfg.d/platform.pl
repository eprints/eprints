# platform eprints is running on
if( $^O eq "MSWin32" )
{
	$c->{platform} = 'win32';
}
else
{
	$c->{platform} = 'unix';
}
