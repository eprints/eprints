
######################################################################
#
#  Document file upload information
#
######################################################################

# AT LEAST one of the following formats will be required. If you do
# not want this requirement, then make the list empty (Although this
# means users will be able to submit eprints with ZERO documents.
#
# Available formats are configured elsewhere. See the docs.

$c->{required_formats} = 
[
	"html",
	"pdf",
	"ps",
	"ascii"
];

# if you want to make this depend on the values in the eprint then
# you can make it a function pointer instead. The function should
# return a list as above.

# This example requires all normal formats for all eprints except
# for those of type book where a document is optional.
#
# $c->{required_formats} = sub {
# 	my( $session, $eprint ) = @_;
# 
# 	if( $eprint->get_value( 'type' ) eq "book" )
# 	{
# 		return [];
# 	}
# 	return ['html','pdf','ps','ascii'];
# };

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 64*1024;

# If ever the amount of free space drops below this threshold, the
# repository administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512*1024;


