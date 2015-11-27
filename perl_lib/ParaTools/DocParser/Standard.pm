######################################################################
#
# ParaTools::DocParser::Standard;
#
######################################################################
#
#  This file is part of ParaCite Tools
#
#  Copyright (c) 2002 University of Southampton, UK. SO17 1BJ.
#
#  ParaTools is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  ParaTools is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with ParaTools; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

package ParaTools::DocParser::Standard;
require Exporter;
@ISA = ("Exporter", "ParaTools::DocParser");

use ParaTools::Intl qw( normalise_multichars );
use Encode;
use Text::Unidecode;

use 5.006;
use strict;
use warnings;
use utf8;
use vars qw($DEBUG $SOFT_HYPHEN);

our @EXPORT_OK = ( 'parse', 'new' );

$DEBUG = 0;
$SOFT_HYPHEN = pack("U",0xad);

=pod

=head1 NAME

B<ParaTools::DocParser::Standard> - document parsing functionality

=head1 SYNOPSIS

  use ParaTools::DocParser::Standard;
  use ParaTools::Utils;
  # First read a file into an array of lines.
  my $content = ParaTools::Utils::get_content("http://www.foo.com/myfile.pdf");
  my $doc_parser = new ParaTools::DocParser::Standard();
  my @references = $doc_parser->parse($content);
  # Print a list of the extracted references.
  foreach(@references) { print "-> $_\n"; } 

=head1 DESCRIPTION

ParaTools::DocParser::Standard provides a fairly simple implementation of
a system to extract references from documents. 

Various styles of reference are supported, including numeric and indented,
and documents with two columns are converted into single-column documents
prior to parsing. This is a very experimental module, and still contains
a few hard-coded constants that can probably be improved upon.

=head1 METHODS

=over 4

=item $parser = ParaTools::DocParser::Standard-E<gt>new()

The new() method creates a new parser instance.

=cut

sub new
{
        my($class) = @_;
        my $self = {};
        return bless($self, $class);
}

=pod

=item @lines = $parser->decolumnize($text)

If $text is multi-column de-columnize by moving the right-hand column below the left for each page. Returns the text as separate lines, or an empty list if $text is not idenfified as being multi-column.

=cut

sub decolumnize
{
	my ($self,$str) = @_;

	my @lines = split("\n", _addpagebreaks($str));
warn "Added page breaks\n" if $DEBUG;
	my($pivot, $avelen) = $self->_decolumnise(@lines);
	return () if (!$pivot || $pivot <= 30); # Sanity check the pivot point

	my(@arr1,@arr2,@arrout);
push @arrout, sprintf("pp = %d, avg = %d\n", $pivot, $avelen);
	my $blanks = 0;
	my ($pivotl,$pivotr) = ($pivot-7,$pivot+14); # See oai:arXiv.org:q-bio/0410026
	foreach(@lines)
	{
		chomp;
#		s/^(\s{3,8})(?=\S)//; # Why is this here?
#		$indnt = defined($1) ? $1 : '';
		if (/\f/ || $blanks == 3)
		{
			push @arrout, @arr1;
			push @arrout, _fix_indent(@arr2);
			@arr1 = ();
			@arr2 = ();
			$blanks = 0;
		}
		elsif( /^\s*$/ )
		{
			$blanks++;
		}
		else
		{
			if(/^(.{$pivotl,$pivotr}?)\s{3}(\s{3,})?(\S.*?)$/)
			{
				my ($left,$space,$right) = ($1,$2||'',$3);
				push @arr1, $left if defined($left);
				push @arr2, $space.$right if defined($right);
			}
			else
			{
#				push @arr1, $indnt.$_;
				push @arr1, $_;
			}
		}
	}
	push @arrout, @arr1;
	push @arrout, _fix_indent(@arr2);
	@lines = @arrout;
warn "Decolumnized\n" if $DEBUG;
#warn join "\n", @lines;
	return @lines;
}
	
=pod

=item @references = $parser-E<gt>parse($lines, [%options])

The parse() method takes a string as input (see the get_content()
function in ParaTools::Utils for a way to obtain this), and returns a list
of references in plain text suitable for passing to a CiteParser module. 

=cut

sub parse
{
	my($self, $lines, %options) = @_;
	# Remove trailing junk (see e.g. oai:arXiv.org:gr-qc/9412013)
	if( substr($lines,-1024) =~ tr/a-zA-Z//c > 768 ) {
		if( $lines =~ /^.+((?:\w{3,}[,.]?\s{1,4}){4})/s ) {
			$lines = $&.substr($',0,128) if length($&)/length($lines) < .75;
		} else {
			warn ref($self).": Unable to find anything that wasn't junk!!!\n";
			return ();
		}
warn "Removed junk\n" if $DEBUG;
	}
	$lines = _addpagebreaks($lines);
warn "Added page breaks\n" if $DEBUG;
	my @lines = split("\n", $lines);
	my($pivot, $avelen) = $self->_decolumnise(@lines); 
if( $pivot ) {
	warn "Got pivot point ($pivot,$avelen)\n" if $DEBUG;
} elsif( $DEBUG ) {
	warn "Not decolumnizing\n";
}
	
	my $in_refs = 0;
	my @ref_table = ();
	my $curr_ref = "";
	my @newlines = ();
	my $outcount = 0;
	my @arr1 = ();
	my @arr2 = ();
	my @arrout = ();
	my $indnt = "";
	my $COLUMNIZED;
	if ($pivot && $pivot > 30) # Sanity check the pivot point
	{
		my $blanks = 0;
		my ($pivotl,$pivotr) = ($pivot-7,$pivot+7); # See oai:arXiv.org:q-bio/0410026
		foreach(@lines)
		{
			chomp;
#			s/^(\s{3,8})(?=\S)//; # Why is this here?
#			$indnt = defined($1) ? $1 : '';
			if (/\f/ || $blanks == 3)
			{
				push @arrout, @arr1;
				push @arrout, _fix_indent(@arr2);
				@arr1 = ();
				@arr2 = ();
				$blanks = 0;
			}
			elsif( /^\s*$/ )
			{
				$blanks++;
			}
			else
			{
				if(/^(.{$pivotl,$pivotr}?)\s{3}(\s{3,})?(\S.*?)$/)
				{
					my ($left,$space,$right) = ($1,$2||'',$3);
					push @arr1, $left if defined($left);
					push @arr2, $space.$right if defined($right);
				}
				else
				{
					push @arr1, $indnt.$_;
				}
			}
		}
		push @arrout, @arr1;
		push @arrout, _fix_indent(@arr2);
		@lines = @arrout;
		$COLUMNIZED = 1;
warn "Decolumnized\n" if $DEBUG;
#warn join "\n", @lines;
	}
	my @chopped_lines = _find_ref_section(@lines);
if($DEBUG && @chopped_lines) {
my $str = join(' ',@chopped_lines);
$str =~ s/^\s+//s;
warn "Found ref section start: ".substr($str,0,40)." (".@chopped_lines." lines)\n";
#warn join("\n",@chopped_lines);
} elsif($DEBUG) {
warn "Didn't find ref section!!!\n";
}
	my $prevnew = 0;
	foreach(@chopped_lines)
	{
		chomp;
		if (/^\s*\d+\.?\s*references\s*$/i || /^\s*references[:\.]{0,2}\s*$/i || /REFERENCES:?/ || /Bibliography|References and Notes|References Cited/i )
		{
			$in_refs = 1;
			push @newlines, $' if defined($'); # Capture bad input
			next;
		}
		# footnotes, e.g. oai:cogprints.soton.ac.uk:1570
		if ($in_refs && 
			(/^\s*\b(appendix|table|footnotes|acknowledgements|figure captions)\b/i || /_{6}.{0,10}$/ ||
			 /wish to thank/i || /\b[Ff]ig(ure|\.)\s+\d/ || /FIGURES|FOOTNOTES/ )
	 	)
		{
			$in_refs = 0;
		}

		if (/^\s*$/)
		{
			if ($prevnew) { next; }
			$prevnew = 1;
		}
		else
		{
			$prevnew = 0;
		}

		if (/^\s*\d+\s*$/) { next; } # Page number

		if ($in_refs)
		{
			# Some basic multi-line reference joining code
			my $spaces = /^(\s+)[a-z]/ ? length($1) : 0;
			# Split-word (e.g. oai:eprints.ecs.soton.ac.uk:8007 #23)
			if( @newlines && $newlines[$#newlines] =~ /[a-z]-$/ && /^\s*[a-z]/ ) {
				chop($newlines[$#newlines]);
				$newlines[$#newlines] .= $_;
			# Starts with lowercase and is indented
			} elsif( @newlines && $spaces && _within($spaces,length($newlines[$#newlines]),5) ) {
				s/^\s+//s;
				$newlines[$#newlines] .= $_;
			} else {
				push @newlines, $_;
			}
		}
	}
	
warn "Chopped ref section: ".substr(join('',@newlines),0,40)." ... \n" if $DEBUG && @newlines;
	
#warn "BEGIN REF SECTION\n", join("\n",@newlines), "\nEND REF SECTION\n";
	# Work out what sort of separation is used
	my $type = 0;
	my $TYPE_NEWLINE = 0;
	my $TYPE_INDENT = 1; # First line indented
	my $TYPE_NUMBER = 2;
	my $TYPE_NUMBERSQ = 3;
	my $TYPE_LETTERSQ = 4;
	my $TYPE_INDENT_OTHER = 5; # Other lines indented
	my $TYPE_AUTHOR = 6;
	my $numnum = 0;
	my $numsq = 0;
	my $lettsq = 0;
	my ($indmax,$indmin,$numnew,$ind_type,%indbits);
	$indmin = $indmax = $numnew = 0;

	# We found the ref. section, lets see whether it looks like an indented style
	if( @newlines ) {
		# Remove leading whitespace
		shift @newlines while @newlines && $newlines[0] =~ /^\s*$/;
		# Resume normal processing
		($indmax,$indmin,$numnew,$ind_type,%indbits) = _find_indent(@newlines);
warn "Ref. section indent: indmax=$indmax ($indbits{$indmax}), indmin=$indmin ($indbits{$indmin}), numnew=$numnew, total=".@newlines if $DEBUG;
		my $divisor = $COLUMNIZED ? 5 : 3;
	
		if ($numnew < ($#newlines/2) && # If there's lots of blank lines, it's probably not indented as well
		    int($indmin/2) != int($indmax/2) && # If the two indents are very close, probably not indented
		    $indbits{$indmax} > @newlines/$divisor && # Check we have a significant number of indented lines
			$indbits{$indmin} > @newlines/$divisor &&
		    ($indmax != 0 || $indmin != 0) && # Redundant ... probably
		    $indmax < 24 && $indmin < 24 ) { # If the indent is all over the shop, it's probably just noise
print "Indent found ($indmin [$indbits{$indmin}],$indmax [$indbits{$indmax}]) ($numnew<".($#newlines/2).")\n" if $DEBUG;
			if( $ind_type > -1 ) { # Year-based match
				$type = $ind_type == 1 ?
					$TYPE_INDENT_OTHER :
					$TYPE_INDENT;
			} else {
				$type = $indbits{$indmax} > @newlines/2 ?
					$TYPE_INDENT_OTHER :
					$TYPE_INDENT;
			}
		}

		# is it a long list of lines starting with an uppercase char?
		if( $type == $TYPE_NEWLINE )
		{
			my $uc_starts = grep { /^[A-Z][a-z]/ } @newlines;
print STDERR "found $uc_starts/".@newlines." lines starting with uc chars\n" if $DEBUG;
			if( $uc_starts/@newlines > .75 )
			{
				$type = $TYPE_INDENT;
			}
		}
	}

	# We failed to find the reference section, we'll do a last-ditch effect at finding numbered
	# refs by resetting and running is_sqnum/is_num
	@newlines = @lines unless @newlines;

	my @refs;

	if( @refs = _is_sqnum(@newlines) ) {
		$type = $TYPE_NUMBERSQ;
		@newlines = _realign_sq(@refs);
	} elsif( @refs = _is_num(@newlines) ) {
		$type = $TYPE_NUMBER;
		@newlines = _realign_num(@refs);
	} elsif( @refs = _is_sqlett(@newlines) ) {
		$type = $TYPE_LETTERSQ;
		@newlines = @refs;
	} elsif( @chopped_lines && (@refs = _is_author(@newlines)) ) {
		$type = $TYPE_AUTHOR;
		@newlines = @refs;
	}

	if ($type == $TYPE_NEWLINE)
	{
warn "type = NEWLINE: " . substr(join('',@newlines),0,40) if $DEBUG;
		my $indmin = $indmin>5 ? $indmin + 3 : 5;
		foreach(@newlines)
		{
			if (/^\s*$/)
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = "";
				next;
			}
			# Indented line amongst justified text, attach to the previous reference
			elsif( /^\s{$indmin}/ ) {
				s/^\s*(.+)\s*$/$1/;
				if( !$curr_ref && @ref_table ) {
					$ref_table[$#ref_table] .= " ".$_;
					next;
				}
			}
			# Trim off any whitespace surrounding chunk
			s/^\s*(.+)\s*$/$1/;
			s/^(.+)[\\-]+$/$1/;
			if ($curr_ref =~ /http:\/\/\S+$/) {
				$curr_ref = $curr_ref.$_;
			} else {
				$curr_ref .= " ".$_;  
			}
		}
		if ($curr_ref) { push @ref_table, $curr_ref; }
	}		
	# First line indented
	elsif ($type == $TYPE_INDENT)
	{
warn "type = INDENT" if $DEBUG;
		foreach(@newlines)
		{
			if (/^(\s*)\b/ && length $1 == $indmin)
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = $_;
			}
			else
			{
				# Trim off any whitespace surrounding chunk
				s/^\s*(.+)\s*$/$1/;
				if ($curr_ref =~ /http:\/\/\S+$/) { $curr_ref = $curr_ref.$_;} else
				{
					$curr_ref = $curr_ref." ".$_;  
				}

			}
		}
		if ($curr_ref) { push @ref_table, $curr_ref; }
	}
	# First line not indented, others indented
	elsif ($type == $TYPE_INDENT_OTHER)
	{
warn "type = INDENT_OTHER" if $DEBUG;
		foreach(@newlines)
		{
warn "=$_\n" if $DEBUG > 1;
			if (!$curr_ref ) { $curr_ref = $_; }
			elsif (/^(\s+)\S/ && _within(length($1),$indmax,2))
			{
				s/^\s+//;
				if( $curr_ref =~ s/(?<=\w)\-\s*$// ) {
					$curr_ref .= $_;
				} else {
					$curr_ref .= " ".$_;
				}
			}
			else
			{
				# Trim off any whitespace surrounding chunk
				if ($curr_ref =~ /http:\/\/\S+$/)
				{
					s/^\s*(.+)\s*$/$1/;
					$curr_ref .= $_;
				}
				elsif( /\S/ )
				{
					if ($curr_ref) { push @ref_table, $curr_ref; }
					$curr_ref = $_;
				}
			}
		}
		if ($curr_ref) { push @ref_table, $curr_ref; }
	}
	elsif ($type == $TYPE_NUMBER)
	{
warn "type = NUMBER" if $DEBUG;
		my $lastnum = 0;
		my ($one,$two) = (1,2);
		for(@newlines)
		{
			s/^\s*(.+)\s*$/$1/;
			if( /^(\d+)\.?(([\s_]{8}\s*[,a;])|\s+[[:alnum:]_]).+$/ && $1 == $lastnum+1 )
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = $_;
				$lastnum++;
				next;
			}
			else
			{
				if ($curr_ref =~ /http:\/\/\S+$/) {
					$curr_ref = $curr_ref.$_;
				} else {
					$curr_ref = $curr_ref." ".$_;  
				}

			}
		}
		if ($curr_ref) { push @ref_table, $curr_ref; }
		@ref_table = @newlines;
	}
	elsif ($type == $TYPE_NUMBERSQ)
	{
warn "type = NUMBERSQ" if $DEBUG;
		my $lastnum = 1;
		foreach(@newlines)
		{
			s/^\s*(.+)\s*$/$1/;
			# If we have an end of reference section marker, break out
			if ( $lastnum>5 && (my $rem = _end_of_section($_)) ) {
				push @ref_table, $curr_ref if $curr_ref;
				$curr_ref = $rem;
				last;
			}
			# () used in oai:arXiv.org:math-ph/9805026
			elsif( /^[\(\[] ?($lastnum)[\]\)]\s.+$/s ||
		   		(/^[\(\[] ?($lastnum)[\]\)].+$/s && $lastnum>5)	)
			{
				push @ref_table, $curr_ref if defined($curr_ref);
				$curr_ref = $_;
				$lastnum++;
			}
			elsif( $_ eq '' && !$COLUMNIZED ) # Blank line (oai:arXiv.org:cond-mat/0504568 screws up)
			{
				push @ref_table, $curr_ref if defined($curr_ref);
				undef $curr_ref;
			}
			elsif($curr_ref)
			{
				if ($curr_ref =~ /\bhttps?:\/\/\S+$/) {
					$curr_ref .= $_;
				} else {
					$curr_ref .= " ".$_; 
				}

			}
		}
		push @ref_table, $curr_ref if $curr_ref;
	}
	elsif( $type eq $TYPE_LETTERSQ )
	{
warn "type = LETTERSQ" if $DEBUG;
		foreach(@newlines)
		{
			s/^\s*(.+)\s*$/$1/;
			# () used in oai:arXiv.org:math-ph/9805026
			if (/^[\(\[](\w+)[\]\)]\s.+$/s )
			{
				push @ref_table, $curr_ref if $curr_ref;
				$curr_ref = $_;
			}
			elsif( /^\s*$/ ) # Blank line
			{
				push @ref_table, $curr_ref if $curr_ref;
				$curr_ref = undef;
			}
			elsif($curr_ref)
			{
				if ($curr_ref =~ /http:\/\/\S+$/) {
					$curr_ref .= $_;
				} else {
					$curr_ref .= " ".$_; 
				}

			}
		}
		push @ref_table, $curr_ref if $curr_ref;
	} elsif( $type == $TYPE_AUTHOR ) {
warn "type = AUTHOR" if $DEBUG;
		@ref_table = @newlines;
	}

	my @refs_out = ();
	# A little cleaning up before returning
	my $prev_author;
	for (@ref_table)
	{
		# Fix PDF's intl char weirdness
		$_ = normalise_multichars($_);
		s/([[:alpha:]])\-\s+/$1/g; # End of a line hyphen
		{
			use bytes;
			s/$SOFT_HYPHEN/-/sog;
		}
		s/^\s*([\[\(])([^\]\)]+)([\]\)])(.+)$/$1$2$3 $4/s;
		# Same author as previous citation
		$prev_author && s/^((?:[\(\[]\w+[\)\]])|(?:\d{1,3}\.))[\s_]{8,}/$1 $prev_author /;
		if( /^(?:(?:[\(\[]\w+[\)\]])|(?:\d{1,3}\.))\s*([^,]+?)(?:,|and)/ ) {
			$prev_author = $1;
		} else {
			undef $prev_author;
		}
		s/\s+/ /g;
		s/^\s*(.+)\s*$/$1/;
#		next if length $_ > 200;
		push @refs_out, $_ if /\w/s;
	}

	warn "DONE [".@refs_out." found]" if $DEBUG;
	
	# Do a last, desperate sanity check
	# If the average length of the first 10 (or fewer) refs is greater than 500 chars give up
	if( @refs_out ) {
		my ($sum, $i);
		for($sum = 0, $i = 0; $i < 10 && $i < @refs_out; $i++) { $sum += length($refs_out[$i]) }
		my $avg = $sum / $i;
		warn "WARNING: Excessively long refs ($sum / $i = $avg), returning nothing" &&
			return () if( $avg > 500 );
	}
	return @refs_out;
}

# Private method to determine if/where columns are present.
# Relies on odd/even pages being about the same
# Supports only 2-column docs

sub _decolumnise 
{
	my($self, @lines) = @_;
	my @bitsout;
	my @lens = (0); # Removes need to check $lens[0] is defined
	# xpdf 3.00 tends to shift lines in the right-column up a line, leaving the left blank
	# e.g. oai:eprints.ecs.soton.ac.uk:7297
	for(my $i = 0; $i < $#lines; $i++) {
		next unless $lines[$i] =~ /(\s+)\w/;
		next unless length($1) > 30;
		next unless length($lines[$i+1]) < length($1);
		next unless $lines[$i+1] =~ /\w/;
		# Join the lines
		my $line = $lines[$i+1] . substr($lines[$i],length($lines[$i+1]));
		splice(@lines,$i,2,$line);
	}
	foreach(@lines)
	{
		# Replaces tabs with 8 spaces
		s/\t/        /g;
		# Ignore lines that are >75% whitespace (probably diagrams/equations)
		next if( length($_) == 0 || (($_ =~ tr/ //)/length($_)) > .75 );
		# Count lines together that vary slightly in length (within 5 chars)
		$lens[int(length($_)/5)*5+2]++;
		# Split into characters
		my @bits = map { $_ == 32 ? 1 : 0 } unpack "c*", $_;
		for(my $i=0; $i<$#bits; $i++) { $bitsout[$i]+=$bits[$i]; } 
	}
warn "DECOL: Done counting\n" if $DEBUG;
	# Calculate the average length based on the modal.
	# 2003-05-14 Fixed by tdb
	my $avelen = 0;
	for(my $i = 0; $i < @lens; $i++ ) {
		next unless defined $lens[$i];
		$avelen = $i if $lens[$i] > $lens[$avelen];
	}
	my $maxpoint = 0;
	my $max = 0;
	# Determine which point has the most spaces
	for(my $i=0; $i<$#bitsout; $i++) {
		if ($bitsout[$i] > $max) {
			$max = $bitsout[$i];
			$maxpoint = $i;
		}
	}
	my $center = int($avelen/2);
	my $output = 0;
warn "DECOL: Found centre/maxpoint: $center/$maxpoint\n" if $DEBUG;
	# Only accept if the max point lies near the average center.
	if ($center-6 <= $maxpoint && $center+6 >= $maxpoint) { $output = $maxpoint; } else  {$output = 0;}
#warn "Decol: avelen=$avelen, center=$center, maxpoint=$maxpoint (output=$output)\n";
	return ($output, $avelen); 
}

# Find the inner & outer most common indents + no. newlines
sub _find_indent {
	my ($numnew,%indbits,%yearin);
	for(@_)
	{
#print "blanks: $numnew, nums: $numnum, numsq: $numsq, lettsq: $lettsq '"._remove_ff(substr($_,0,50))."'\n" if $DEBUG;
		if (/^\s*$/)
		{
			$numnew++;
		}
		# To find the indent we look for the two most common indents
		if (/^(\s*)\S/)
		{
			$indbits{length($1 || '')}++;
			$yearin{length($1 || '')}++ if /^\s*.{0,40}\b[12]\d{3}/;
		}
	}
	my ($indmax,$indmin) = sort { $indbits{$b} <=> $indbits{$a} } keys %indbits;
	$indmax ||= 0;
	$indmin ||= 0;
	$numnew ||= 0;
	if( $indmax < $indmin ) {
		my $t = $indmin;
		$indmin = $indmax;
		$indmax = $t;
	}
	if( abs($indmax-$indmin) >= 4 ) {
		for($indmax,$indmin) {
			if( exists($indbits{$_-1}) && $indbits{$_-1}*3 > $indbits{$_} ) {
				$indbits{$_} += $indbits{$_-1};
				$indbits{$_-1} = 0;
				$yearin{$_} += $indbits{$_-1};
				$yearin{$_-1} = 0;
			} elsif( exists($indbits{$_+1}) && $indbits{$_+1}*3 > $indbits{$_+1} ) {
				$indbits{$_} += $indbits{$_+1};
				$indbits{$_+1} = 0;
				$yearin{$_} += $indbits{$_+1};
				$yearin{$_+1} = 0;
			}
		}
	}
	my $type;
	$yearin{$indmin} ||= 0;
	$yearin{$indmax} ||= 0;
	if( $yearin{$indmin} > @_/6 || $yearin{$indmax} > @_/6 ) {
		$type = ( $yearin{$indmin} > $yearin{$indmax} ) ?
			1 :
			0;
	} else {
		$type = -1;
	}
#warn "Found indmax=$indmax, indmin=$indmin, numnew=$numnew" if $DEBUG;
	return ($indmax,$indmin,$numnew,$type,%indbits);
}

sub _fix_indent {
	my ($indmax,$indmin) = _find_indent(@_);
	$indmin = $indmax < $indmin ? $indmax : $indmin;
	for(@_) {
		s/^ {$indmin}//;
	}
	@_;
}

# Remove header/footers around formfeeds

sub _clear_ff
{
	my $doc = shift;
	my (%HEADERS,%FOOTERS);
	while( $doc =~ /([^\n]+\n)\f([\r\n]*[^\n]+\n)/osg ) {
		$FOOTERS{_header_to_regexp($1)}++;
#		$HEADERS{_header_to_regexp($2)}++;
	}

	#warn "Found footers: ", join("\n", %FOOTERS);
	#warn "Found headers: ", join("\n", %HEADERS);

	for( grep { $FOOTERS{$_} > 3 } keys %FOOTERS ) {
		$doc =~ s/$_\f/\f/sg;
	}
	# Headers can be a problem running off into the next page: astro-ph/0406663
	for( grep { $HEADERS{$_} > 3 } keys %HEADERS ) {
		$doc =~ s/\f$_/\f/sg;
	}

	#$doc =~ s/\f/\n/sg; # Why did I do this?!

	$doc;
}

# Private function that replaces header/footers with form feeds

sub _addpagebreaks {
	my $doc = shift;
	return _clear_ff($doc) if $doc =~ /\f/s;
	my %HEADERS;

	while( $doc =~ /(?:\n[\r[:blank:]]*){2}([^\n]{0,40}\w+[^\n]{0,40})(?:\n[\r[:blank:]]*){3}/osg ) {
		$HEADERS{_header_to_regexp($1)}++;
	}

	if( %HEADERS ) {
		my @regexps = sort { $HEADERS{$b} <=> $HEADERS{$a} } keys %HEADERS;
		my $regexp = $regexps[0];
		if( $HEADERS{$regexp} > 3 ) {
			my $c = $doc =~ s/(?:\n[\r[:blank:]]*){2}(?:$regexp)(?:\n[\r[:blank:]]*){3}/\f/sg;
#warn "Applying regexp: $regexp ($HEADERS{$regexp} original matches) Removed $c header/footers using ($HEADERS{$regexp} original matches): $regexp\n" if $DEBUG;
		} else {
			warn "Not enough matching header/footers were found ($HEADERS{$regexp} only)" if $DEBUG;
		}
	} else {
		warn "Header/footers not found - flying blind if this is a multi-column document" if $DEBUG;
	}

	return $doc;
}

sub _header_to_regexp {
	my $header = shift;
	$header =~ s/([\\\|\(\)\[\]\.\*\+\?\{\}])/\\$1/g;
	$header =~ s/\s+/\\s+/g;
	$header =~ s/\d+/\\d+/g;
	return $header;
}

sub _find_ref_section {
	my @lines = @_;
	my @ref_section;

	my $score = 1000;
	my $line = -1;
	for(my $i = 0; $i < @lines; $i++) {
		if( $line == -1 && $lines[$i] =~ /REFERENCES|BIBLIOGRAPHY/ ) {
print STDERR "Found ref. heading: ".substr($lines[$i],0,80). "\n" if $DEBUG;
			$line = $i;
			$score = "$` $'" =~ tr/[a-zA-Z0-9]//;
		} elsif( $lines[$i] =~ /\breferences|bibliography|\s{5,}cited/i ) {
print STDERR "Found ref. heading: ".substr($lines[$i],0,80). " ... " if $DEBUG;
			my $junk = "$` $'" =~ tr/[a-zA-Z0-9]//;
			if( $junk <= $score && $junk < length($lines[$i])/3 ) {
print STDERR "[Passed]\n" if $DEBUG;
				$line = $i;
				$score = $junk;
			} else {
print STDERR "[Failed]\n" if $DEBUG;
			}
		}
	}
	return $line > -1 ? splice(@lines,$line-1) : ();
}

sub _end_of_section
{
	$_ = shift if @_;
	return (
		/^\s*\b(appendix|table|footnotes)\b/i ||
		/wish to thank/i ||
		/\b[Ff]ig(ure|\.)\s+\d/ ||
		/FIGURES|FOOTNOTES/
	) ? $` : undef;
}

# Indented can either be first line, or all other lines
sub _indented {
	my @lines = @_;

	my %bits;
	for(@lines) {
		/^\s*/;
		$bits{length($& || '')}++;
	}
	my ($l,$r) = sort { $bits{$b} <=> $bits{$a} } keys %bits;
	return ($l,$r);
}

sub _is_sqnum_alt {
	my $ref_sect = '';
	for(@_) {
		if( $ref_sect =~ s/(?<=\w)-$// ) {
			s/^\s+//;
			$ref_sect .= $_;
		} else {
			$ref_sect .= ' ' . $_;
		}
	}

	my $brack_re = '\[\(';
	my %brack_match = ('[' => '\]','(' => '\)');
	my @nums;
	# Find the last number in brackets, and work our way back
	while( $ref_sect =~ /(?<!\d)([$brack_re]) *(\d{1,3})[\]\)]/sog ) {
warn "Found sqnum: '$1' => $2\n" if $DEBUG;
		push @nums, [$1,$2];
	}
	@nums = splice(@nums,-30) if @nums > 30;
	# This would fail horribly if the document contains a repeated,
	# bracketed number with a series at the beginning of the doc
	while(my $num_series = pop @nums) {
		my ($type,$top) = @$num_series;
		my $type_close = $brack_match{$type};
		next if $top < 5; # Less than 5 refs is most likely matching junk
		my $re;
		for(1..$top) {
			$re .= "(\\".$type." *".$_."$type_close.{20,1000})";
		}
#warn "Searching for $re\n" if $DEBUG;
		if( $ref_sect =~ /$re/s ) {
			my @refs;
			for(1..$top) {
				eval "push \@refs, \$$_";
			}
warn "Found ref section: ".join("\n",@refs)."\n" if $DEBUG;
			return @refs;
		}
	}
	return ();
}

sub _is_sqnum {
	return _is_sqnum_alt(@_);
	use utf8;
	# Handle numbered references joined together (e.g. bad to-text conversion)
	my $ref_sect = join "\n", @_;
	my $ref_b = 1; my $ref_e = 2;
	my $max_ref_len = 1000;
	my @num_refs;
	my $brack_type = '\[\(';
	# math.PH/0403001 fails if the max ref length is 300 (long reference for #2)
	my $prev = -1;
	my $post_prev = 0;
	# Don't match volume(issue), e.g. oai:eprints.ecs.soton.ac.uk:10638
	while( $ref_sect =~ /(?<!\d)(([$brack_type]) *$ref_b[\)\]])/sg ) {
warn "NUMBERSQ: Matched $ref_b (type = $2): ".substr($ref_sect,pos($ref_sect),40)."\n" if $DEBUG;
		$ref_b++;
		$brack_type = $2;
		if( $prev >= 0 ) {
			my $ref = substr($ref_sect,$prev,pos($ref_sect)-length($1)-$prev);
			if( ($ref_b < 4 && length($ref) > 1000) || length($ref) > 2000 ) {
				# Skip over the first number and try again!
				return _is_sqnum(substr($ref_sect,$post_prev));
			}
#warn "Ref # = " . $ref;
			push @num_refs, split /\n/, $ref;
		}
		$prev = pos($ref_sect)-length($1);
		$post_prev = pos($ref_sect);
	}
	if( $prev < length($ref_sect) ) {
		push @num_refs, split /\n/, substr($ref_sect,$prev);
	}
	if( $ref_b >= 4 ) {
warn "NUMBERSQ: Found $ref_b citations (type = '$brack_type')\n" if $DEBUG;
		return @num_refs;
	}
	();
}

=pod

=item _is_num(@lines)

Find a reference section based on numbered lines (returns the last matching set).

=cut

sub _is_num_alt {
	my $ref_sect = "\n";
	# Join hyphenated lines together
	for(@_) {
		if( $ref_sect =~ s/(?<=\w)-\n$//s ) {
			s/^\s+//;
			$ref_sect .= $_;
		} else {
			$ref_sect .= $_;
		}
		$ref_sect .= "\n";
	}

	my @nums;
	# Find the last numbers in sequence at line beginnings (between 5 and 999)
	while( $ref_sect =~ /^ *([1-9]\d{0,2})\b/mog ) {
		next unless $1 >= 5;
		if( @nums == 0 ) {
			push @nums, $1;
		} elsif( $nums[-1]+1 == $1 ) {
			$nums[-1] = $1;
		} else {
			push @nums, $1;
		}
	}
	@nums = splice(@nums,-30) if @nums > 30;
warn "Found nums: ", join(',',@nums), "\n" if $DEBUG;
	# This relies on the references being at the end,
	# and not being followed by another numbered list
	my %seen;
	while(my $top = pop @nums) {
		next if $seen{$top};
		$seen{$top} = 1;
		use bytes;
		my $re;
		for(1..$top) {
			$re .= "\\n([ \\t]*".$_."\\D.{10,".($_>5?2000:1000)."})";
		}
#warn "Searching for $re\n" if $DEBUG;
		my @refs = $ref_sect =~ /$re/;
		return @refs if @refs;
	}
#warn "Didn't find ref section\n" if $DEBUG;
	return ();
}

# This is broken, as it finds the first matching section :-(

sub _is_num {
	return _is_num_alt(@_);
	my $doc = join "\n", @_;
	my ($one,$two,$thr) = (1,2,3);
	my @num_refs;
	# Chop up to 300 chars off the front until we get a 1.
#warn "_is_num: \$doc = ".substr($doc,0,50);
	while( $doc =~ s/^.*?\b($one(\.\s|\s{4}))//s ) {
		my $ref_sect = $1.$doc;
		my $type = $2; $type =~ s/\./\\./;
#warn "(($one$type.{15,500}?)(?=\b$two$type)) => type = $type, ref_sect = ".substr($ref_sect,0,500)."\n";
		while( $ref_sect =~ s/^($one$type.{15,500}?)(?=\b$two$type)//s ) {
#warn "Found ref: $1\n";
#warn "ref_sect = ".substr($ref_sect,0,500)."\n";
			#push @num_refs, split(/\n/, $1);
			push @num_refs, $1;
			$one++; $two++;
		}
		if( $one >= 4 ) {
			push @num_refs, split(/\n/, $ref_sect) if defined($ref_sect);
warn "Found ref section _is_num [$one]\n" if $DEBUG;
			return @num_refs;
		}
		($one,$two,$thr) = (1,2,3);
		@num_refs = ();
	}
	();
}

sub _is_sqlett {
	# Handle numbered references joined together (e.g. bad to-text conversion)
	my $ref_sect = join "\n", @_;
	my @refs = split(/([\[\(][A-Za-z]\w+[\]\)])/, $ref_sect) or return ();
	my $good_split = 0;
	# If we split correctly then there should be only one year in at least one of the middle three refs
	for(my $i = int($#refs)/2; $i < int($#refs/2+3) && defined($refs[$i]); $i++) {
		if( ($refs[$i] =~ s/([12]\d{3})/$1/sg) == 1 ) {
			$good_split = 1;
			last;
		}
	}
	return unless $good_split;
	for( my $i = 0; $i < @refs; $i++ ) {
		# Eds needs to be caught, e.g. oai:arXiv.org:cs/0101012
		if( $refs[$i] =~ /\(Eds?\)/i && $i > 0 ) {
			$refs[$i-1] .= splice(@refs,$i,1);
			$i--; next;
		}
		if( $refs[$i] !~ /^[\[\(][A-Za-z]\w+[\]\)]$/ ) {
			$refs[$i-1] .= splice(@refs,$i,1);
			$i--;
		} else {
warn "Found sqlett at line $i: $refs[$i]" if $DEBUG;
		}
	}
	if( @refs >= 4 ) {
		return @refs;
	}
	();
}

sub _is_author {
	my @lines = grep { /\S/ } @_;
	# e.g. astro-ph/9403035, gr-qc/0005044
	# Handle a block of references that aren't indented/separated by newlines
	# Author names formats covered:
	# 	O'Rourke, T
	# 	Moreno-Garrido C.
	my @authlines = grep { /^\s*[A-Z]'?[\w]{3,}(?:-\w{3,})?,?\s+[A-Z](\.|\w+).{0,50}\d{4}/o } map { unidecode($_) } @lines;
	return unless @authlines;
	return () unless( @authlines/@lines > .80 );
	# This is two-phased to allow refs without a year after authors
	@authlines = ();
	my $cur_ref;
	for(@lines) {
		if( !$cur_ref ) {
			$cur_ref = $_;
		} elsif( unidecode($_) =~ /^\s*[A-Z]'?[\w]{3,}(?:-\w{3,})?,?\s+[A-Z](\.|\w+\b)/ ) {
			push @authlines, $cur_ref;
			$cur_ref = $_;
		} else {
			$cur_ref .= " " . $_;
		}
	}
	push @authlines, $cur_ref if $cur_ref;
	return @authlines;
}

# Fix e.g. oai:arXiv.org:gr-qc/9412013
# [1] a reference
#     a reference
# [2]			# This is assumed to be previous line
#
#     a reference
# [3]
# [4] a reference
# 
sub _realign_sq {
	my @lines = @_;

	my $lastnum = 0;
	my $preamble;
	my @refs;
	for(@lines) {
		s/^\s+//s;
		if( /^[\[\(] ?(\d+)[\]\)]/ && $1 == $lastnum+1 ) {
			push @refs, [$_];
			$lastnum++;
		} elsif( @refs ) {
			push @{$refs[$#refs]}, $_;
		} else {
			$preamble = $_;
		}
	}
	for(my $i = 0; $i < @refs; $i++) {
		my ($num,@rest) = @{$refs[$i]};
		if( $num =~ /^[\[\(] ?(\d+)[\]\)]\s*$/s ) {
			if( @rest == 0 || $rest[0] eq '' ) { # Must be the line before
				if( $i > 0 && @{$refs[$i-1]} > 1 ) {
					$refs[$i]->[0] .= " " . pop @{$refs[$i-1]};
				} elsif( $i == 0 && defined($preamble) ) {
					$refs[$i]->[0] .= " " . $preamble;
				}
			} else { # Must be the unnumbered line after
				$refs[$i]->[0] .= splice(@{$refs[$i]},1,1);
			}
		}
	}
	return map { @$_ } @refs;
}
sub _line_above_empty {
	my ($c,@lines) = @_;
	return $#lines-$c > 0 ? $lines[$#lines-$c] eq '' : undef;
}
sub _realign_num {
	my @lines = @_;

	my $lastnum = 0;
	my $preamble;
	my @refs;
	for(@lines) {
		s/^\s+//s;
		if( /^(\d+)\.?\b/ && $1 == $lastnum+1 ) {
			push @refs, [$_];
			$lastnum++;
		} elsif( @refs ) {
			push @{$refs[$#refs]}, $_;
		} else {
			$preamble = $_;
		}
	}
	for(my $i = 0; $i < @refs; $i++) {
		my ($num,@rest) = @{$refs[$i]};
		if( $num =~ /^(\d+)\.?\s*$/s ) {
			if( @rest == 0 || $rest[0] eq '' ) { # Must be the line before
				if( $i > 0 && @{$refs[$i-1]} > 1 ) {
					$refs[$i]->[0] .= " " . pop @{$refs[$i-1]};
				} elsif( $i == 0 && defined($preamble) ) {
					$refs[$i]->[0] .= " " . $preamble;
				}
			} else { # Must be the unnumbered line after
				$refs[$i]->[0] .= " " . splice(@{$refs[$i]},1,1);
			}
warn "Re-aligning reference $1: ".$refs[$i]->[0]."\n" if $DEBUG;
		}
	}
	return map { @$_ } @refs;
}

sub _within {
	my ($l,$r,$p) = @_;
#warn "Is $l with $p of $r?\n";
	return $r >= $l-$p && $r <= $l+$p;
}

sub _remove_ff {
	$_[0] =~ s/[\f\n]/ /sg;
	$_[0];
}

1;

__END__

=back

=pod

=head1 CHANGES

- 2003/05/13
	Removed Perl warnings generated from parse() by adding checks on the regexps

=head1 AUTHOR

Mike Jewell <moj@ecs.soton.ac.uk>
Tim Brody <tdb01r@ecs.soton.ac.uk>

=cut
