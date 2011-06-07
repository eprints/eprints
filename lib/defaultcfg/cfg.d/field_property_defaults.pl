
######################################################################
#
#  Field Property Defaults
#
######################################################################

# This lets you set the default values for 
# certain cosmetic properties of metadata fields
# rather than set them individually. Settings on
# a metafield will override these values.

# Number of rows of a textarea input or max number of elements before
# a scrollbar appears in sets, subjects and namedset fields. A value
# of ALL will show all the settings in a set, subject or namedset.
$c->{field_defaults}->{input_rows} = 10;

# Number of columns (characters) of a textarea input or text
# input field.
$c->{field_defaults}->{input_cols} = 60;

# Default size of the "name" input field parts.
$c->{field_defaults}->{input_name_cols} = {
	honourific=>8,
	given=>20,
	family=>20,
	lineage=>8 
};

# Default number of boxes to add when clicking the "more spaces"
# button on a multiple field.
$c->{field_defaults}->{input_add_boxes} = 2;

# Default number of boxes to show on a multiple field.
$c->{field_defaults}->{input_boxes} = 3;

# Max digits in an integer.
$c->{field_defaults}->{digits} = 20;

# Width of a search field
$c->{field_defaults}->{search_cols} = 40;

# Maximum rows to display in a subject or set search
$c->{field_defaults}->{search_rows} = 12;

# You may hide the "lineage" and "honourific"
# fields in the "name" type field input, if you
# feel that they will confuse your users. This
# makes no difference to the actual database,
# the fields will just be unused.
$c->{field_defaults}->{hide_honourific} = 0;
$c->{field_defaults}->{hide_lineage} = 1;

# By default names are asked for as given,family
# if you want to swap this to family,given then
# set this flag to 1
$c->{field_defaults}->{family_first} = 0;

