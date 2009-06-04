eval "use XML::GDOME";

# set this to 0 to completely disable XML::GDOME
$c->{enable_gdome} = $@ ? 0 : 1;
