
######################################################################
#
#  Document file upload information
#
######################################################################

# This sets the minimum amount of free space allowed on a disk before EPrints
# starts using the next available disk to store EPrints. Specified in kilobytes.
$c->{diskspace_error_threshold} = 64*1024;

# If ever the amount of free space drops below this threshold, the
# repository administrator is sent a warning email. In kilobytes.
$c->{diskspace_warn_threshold} = 512*1024;

# Add an additional MIME type mapping from file extensions
# $c->{mimemap}->{html} = "text/html";

