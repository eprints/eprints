######################################################################
#
# Experimental VLit support.
#
#  VLit support will allow character ranges to be served as well as
#  whole documents.
#
######################################################################

# set this to 0 to disable vlit (and run generate_apacheconf)
$c->{vlit}->{enable} = 1;

# The URL which the (C) points to.
$c->{vlit}->{copyright_url} = $c->{base_url}."/vlit.html";

