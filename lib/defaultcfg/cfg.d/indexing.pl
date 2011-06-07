######################################################################
#
#  Site Text Indexing Configuration
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
# __LICENSE__
#
######################################################################
#
# These values control what words do and don't make it into
# the free text search index. Stemming is allowed : eg. removing 
# "ing" and "s" off the end of word so "looks", "looking" and "look"
# all get indexed as "look". Which is probably helpful.
#
# If you change this file, make sure you cause the indexes to be
# rebuilt or odd things may happen.
#
######################################################################

$c->{index} = 1;

# Minimum size word to normally index.
$c->{indexing}->{freetext_min_word_size} = 3;

# We use a hash rather than an array for good and bad
# words as we only use these to lookup if words are in
# them or not. If we used arrays and we had lots of words
# it might slow things down.

# Words to never index, despite their length.
$c->{indexing}->{freetext_stop_words} = {
	"this"=>1,	"are"=>1,	"which"=>1,	"with"=>1,
	"that"=>1,	"can"=>1,	"from"=>1,	"these"=>1,
	"those"=>1,	"the"=>1,	"you"=>1,	"for"=>1,
	"been"=>1,	"have"=>1,	"were"=>1,	"what"=>1,
	"where"=>1,	"is"=>1,	"and"=>1, 	"fnord"=>1,
};

# Words to always index, despite their length.
$c->{indexing}->{freetext_always_words} = {
		"ok" => 1,
};



# Chars which seperate words. Pretty much anything except
# A-Z a-z 0-9 and single quote '

# If you want to add other seperator characters then they
# should be encoded in utf8.

$c->{indexing}->{freetext_seperator_chars} = {
	'@' => 1, 	'[' => 1, 	'\\' => 1, 	']' => 1,
	'^' => 1, 	'_' => 1,	' ' => 1, 	'`' => 1,
	'!' => 1, 	'"' => 1, 	'#' => 1, 	'$' => 1,
	'%' => 1, 	'&' => 1, 	'(' => 1, 	')' => 1,
	'*' => 1, 	'+' => 1, 	',' => 1, 	'-' => 1,
	'.' => 1, 	'/' => 1, 	':' => 1, 	';' => 1,
	'{' => 1, 	'<' => 1, 	'|' => 1, 	'=' => 1,
	'}' => 1, 	'>' => 1, 	'~' => 1, 	'?' => 1,
};


######################################################################
#
# extract_words( $repository, $text )
#
#  This method is used when indexing a record, to decide what words
#  should be used as index words.
#  It is also used to decide which words to use when performing a
#  search. 
#
#  It returns references to 2 arrays, one of "good" words which should
#  be used, and one of "bad" words which should not.
#
######################################################################

$c->{extract_words} = sub
{
	my( $repository, $text ) = @_;

	# Acronym processing only works on uppercase non accented
	# latin letters. If you don't want this processing comment
	# out the next few lines.

	# Normalise acronyms eg.
	# The F.B.I. is like M.I.5.
	# becomes
	# The FBI  is like MI5
	# These are rather expensive to run, so are being commented out
	# by default. 
	#my $a;
	#$text =~ s#[A-Z0-9]\.([A-Z0-9]\.)+#$a=$&;$a=~s/\.//g;$a#ge;
	# Remove hyphens from acronyms
	#$text=~ s#[A-Z]-[A-Z](-[A-Z])*#$a=$&;$a=~s/-//g;$a#ge;

	# Process string. 
	# First we apply the char_mappings.
	my $buffer = EPrints::Index::apply_mapping( $repository, $text );

	my @words =EPrints::Index::split_words( $repository, $buffer );

	# Iterate over every word (bits divided by seperator chars)
	# We use hashes rather than arrays at this point to make
	# sure we only get each word once, not once for each occurance.
	my %good = ();
	my %bad = ();
	my $word;
	foreach $word ( @words )
	{	
		# skip if this is nothing but whitespace;
		next if ($word =~ /^\s*$/);

		# calculate the length of this word
		my $wordlen = length $word;

		# $ok indicates if we should index this word or not

		# First approximation is if this word is over or equal
		# to the minimum size set in SiteInfo.
		my $ok = $wordlen >= $c->{indexing}->{freetext_min_word_size};
	
		# If this word is at least 2 chars long and all capitals
		# it is assumed to be an acronym and thus should be indexed.
		if( $word =~ m/^[A-Z][A-Z0-9]+$/ )
		{
			$ok=1;
		}

		# Consult list of "never words". Words which should never
		# be indexed.	
		if( $c->{indexing}->{freetext_stop_words}->{lc $word} )
		{
			$ok = 0;
		}
		# Consult list of "always words". Words which should always
		# be indexed.	
		if( $c->{indexing}->{freetext_always_words}->{lc $word} )
		{
			$ok = 1;
		}
	
		# Add this word to the good list or the bad list
		# as appropriate.	
		unless( $ok )
		{
			$bad{$word}++;
			next;
		}

		# Only "bad" words are used in display to the
		# user. Good words can be normalised even further.

		# non-acronyms (ie not all UPPERCASE words) have
		# a trailing 's' removed. Thus in searches the
		# word "chair" will match "chairs" and vice-versa.
		# This isn't perfect "mose" will match "moses" and
		# "nappy" still won't match "nappies" but it's a
		# reasonable attempt.
		$word =~ s/s$//;

		# If any of the characters are lowercase then lower
		# case the entire word so "Mesh" becomes "mesh" but
		# "HTTP" remains "HTTP".
		if( $word =~ m/[a-z]/ )
		{
			$word = lc $word;
		}

		$good{$word}++;
	}
	# convert hash keys to arrays and return references
	# to these arrays.
	my( @g ) = keys %good;
	my( @b ) = keys %bad;

	return( \@g , \@b );
};

