if( !defined $c->{enable_libxml} )
{
	eval "use XML::LibXML 1.63";

	# set this to 0 to completely disable XML::LibXML
	$c->{enable_libxml} = $@ ? 0 : 1;
}
