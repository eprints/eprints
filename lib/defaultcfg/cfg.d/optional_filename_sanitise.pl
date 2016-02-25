#$c->{optional_filename_sanitise} = sub
#{
#	my ($repo, $filepath) = @_;
#
#	# To sanitise characters that get encoded in HTTP, or for any other reason
#	# Uncomment any of these substitutions to use them or add your own
#
#	#$filepath =~ s!\s!_!g; # convert white space to underscore
#	#$filepath =~ s!\x28!_!g; # convert left bracket to underscore
#	#$filepath =~ s!\x29!_!g; # convert right bracket to underscore
#	#$filepath =~ s!\x40!_!g; # convert at sign to underscore
#
#	return $filepath;
#
#};
