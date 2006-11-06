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

use 5.006;
use strict;
use warnings;
use vars qw($DEBUG);

our @EXPORT_OK = ( 'parse', 'new' );

$DEBUG = 0;

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

=item @references = $parser-E<gt>parse($lines, [%options])

The parse() method takes a string as input (see the get_content()
function in ParaTools::Utils for a way to obtain this), and returns a list
of references in plain text suitable for passing to a CiteParser module. 

=cut

sub parse
{
	my($self, $lines, %options) = @_;
	$lines = _addpagebreaks($lines);
	my @lines = split("\n", $lines);
	my($pivot, $avelen) = $self->_decolumnise(@lines); 
	
	my $in_refs = 0;
	my @ref_table = ();
	my $curr_ref = "";
	my @newlines = ();
	my $outcount = 0;
	my @chopped_lines = @lines;
	# First isolate the reference array. This ensures that we handle columns correctly.
	foreach(@lines)
	{
		s/\015?\012?$//s;
		$outcount++;
		if (/(?:references)|(?:bibliography)|(?:\s+cited)/i)
                {
                        last;
                }
		elsif (/\f/)
		{
			# No sign of any references yet, so pop off up to here
			for(my $i=0; $i<$outcount; $i++) { shift @chopped_lines; }
			$outcount = 0;
		}
	}
	my @arr1 = ();
	my @arr2 = ();
	my @arrout = ();
	my $indnt = "";
	if ($pivot)
	{
		foreach(@chopped_lines)
		{
			s/\015?\012?$//s;
			s/^(\s{3,8})(?=\S)//;
			$indnt = defined($1) ? $1 : '';
			if (/\f/)
			{
				push @arrout, @arr1;
				push @arrout, @arr2;
				@arr1 = ();
				@arr2 = ();
			}
			else
			{
				
				if(/^(.+?)\s\s\s+(.*?)$/)
				{
					push @arr1, $indnt.$1;
					push @arr2, $2 if defined($2);
				}
				else
				{
					push @arr1, $indnt.$_;
				}
			}
		}
		push @arrout, @arr1;
		push @arrout, @arr2;
		@chopped_lines = @arrout;
	}
	my $prevnew = 0;
	foreach(@chopped_lines)
	{
		s/\015?\012?$//s;
		if (/^\s*references\s*$/i || /REFERENCES/ || /Bibliography/i || /References and Notes/)
                {
                        $in_refs = 1;
			push @newlines, $' if defined($'); # Capture bad input
                        next;
                }
		if (/^\s*\bappendix\b/i || /_{6}/ || /^\s*\btable\b/i || /wish to thank/i || /\bfigure\s+\d/)
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
			push @newlines, $_;
		}
	}
#warn "BEGIN REF SECTION\n", join("\n",@newlines), "\nEND REF SECTION\n";
	# Work out what sort of separation is used
	my $type = 0;
	my $TYPE_NEWLINE = 0;
	my $TYPE_INDENT = 1;
	my $TYPE_NUMBER = 2;
	my $TYPE_NUMBERSQ = 3;
	my $numnew = 0;
	my $numnum = 0;
	my $numsq = 0;
	my $indmin = 255;
	my $indmax = 0;
	# Handle numbered references joined together (e.g. bad to-text conversion)
	my $ref_sect = join "\n", @newlines;
	my $ref_b = 1; my $ref_e = 2;
	my @num_refs;
	while( $ref_sect =~ s/(\[$ref_b\].+?)(?=\[$ref_e\])//sg ) {
		$ref_b++; $ref_e++;
		push @num_refs, split("\n", $1);
	}
	if( $ref_b >= 5 ) {
		@newlines = @num_refs;
		push @newlines, $ref_sect if defined($ref_sect);
	}
	# Resume normal processing
	foreach(@newlines)
	{
		if (/^\s*$/)
		{
			$numnew++;
		}
		if (/^(\s+)\b/)
		{
			if (length $1 < $indmin) { $indmin = length $1; }
			if (length $1 > $indmax) { $indmax = length $1; }
		}
		if (/^\s*\d+\.?\s+[[:alnum:]]/)
		{
			$numnum++;
		}
		if (/^\s*[\[\(]\d+[\]\)]\s+[[:alnum:]]/)
		{
			$numsq++;	
		}
	}
	
#	if ($numnew < ($#newlines-5) && ($indmax > $indmin) && $indmax != 0 && $indmin != 255 && $indmax < 24) { $type = $TYPE_INDENT; }
# If references are seperated by blank lines, then we would expect to see around one blank line
# for each reference?
	if ($numnew < ($#newlines/2) && ($indmax > $indmin) && $indmax != 0 && $indmin != 255 && $indmax < 24) { $type = $TYPE_INDENT; }
	if ($numnum > 1) { $type = $TYPE_NUMBER; }
	if ($numsq > 1) { $type = $TYPE_NUMBERSQ; }
	if ($type == $TYPE_NEWLINE)
	{
warn "type = NEWLINE" if $DEBUG;
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
	elsif ($type == $TYPE_INDENT)
	{
warn "type = INDENT" if $DEBUG;
		foreach(@newlines)
		{
			/^(\s*)\b/;
			if (length $1 == $indmin)
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = $_;
				next;
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
	elsif ($type == $TYPE_NUMBER)
	{
warn "type = NUMBER" if $DEBUG;
		foreach(@newlines)
		{
			s/^\s*(.+)\s*$/$1/;
			if (/^\s*\d+\.?\s+[[:alnum:]].+$/)
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = $_;
				next;
			}
			else
			{
				if ($curr_ref =~ /http:\/\/\S+$/) { $curr_ref = $curr_ref.$_;} else
				{
					$curr_ref = $curr_ref." ".$_;  
				}

			}
		}
		if ($curr_ref) { push @ref_table, $curr_ref; }
	}
	elsif ($type == $TYPE_NUMBERSQ)
	{
warn "type = NUMBERSQ" if $DEBUG;
		foreach(@newlines)
		{
			s/^\s*(.+)\s*$/$1/;
			# () used in oai:arXiv.org:math-ph/9805026
			if (/^\s*[\(\[]\d+[\]\)]\s.+$/ )
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				$curr_ref = $_;
			}
			elsif( /^\s*$/ ) # Blank line
			{
				if ($curr_ref) { push @ref_table, $curr_ref; }
				undef $curr_ref;
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
		if ($curr_ref) { push @ref_table, $curr_ref; }
	}

	my @refs_out = ();
	# A little cleaning up before returning	
	foreach (@ref_table)
	{
		s/([[:alpha:]])\-\s+/$1/g;
		s/^\[.+\](.+)$/$1/;
		s/\s\s+/ /g;
		s/^\s*(.+)\s*$/$1/;
		next if length $_ > 200;
		push @refs_out, $_;
	}
	return @refs_out;
}

# Private method to determine if/where columns are present.

sub _decolumnise 
{
	my($self, @lines) = @_;
	my @bitsout;
	my @lens = (0); # Removes need to check $lens[0] is defined
	foreach(@lines)
	{
		# Replaces tabs with 8 spaces
		s/\t/        /g;
		# Ignore lines that are >75% whitespace (probably diagrams/equations)
		next if( length($_) == 0 || (($_ =~ tr/ / /)/length($_)) > .75 );
		# Split into characters
		my @bits = unpack "c*", $_;
		# Count lines together that vary slightly in length (within 5 chars)
		$lens[int(scalar @bits/5)*5+2]++;	
		my @newbits = map { $_ = ($_==32?1:0) } @bits;
		for(my $i=0; $i<$#newbits; $i++) { $bitsout[$i]+=$bits[$i]; } 
	}
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
	for(my $i=0; $i<$#bitsout; $i++) { if ($bitsout[$i] > $max) { $max = $bitsout[$i]; $maxpoint = $i; } }
	my $center = int($avelen/2);
	my $output = 0;
	# Only accept if the max point lies around the average center.
	if ($center-6 <= $maxpoint && $center+6>= $maxpoint) { $output = $maxpoint; } else  {$output = 0;}
#warn "Decol: avelen=$avelen, center=$center, maxpoint=$maxpoint (output=$output)\n";
	return ($output, $avelen); 
}

# Private function that replaces header/footers with form feeds

sub _addpagebreaks {
	my $doc = shift;
	return $doc if $doc =~ /\f/s;
	my %HEADERS;

	while( $doc =~ /(?:\n[\r[:blank:]]*){2}([^\n]{0,40}\w+[^\n]{0,40})(?:\n[\r[:blank:]]*){3}/osg ) {
		$HEADERS{_header_to_regexp($1)}++;
	}

	if( %HEADERS ) {
		my @regexps = sort { $HEADERS{$b} <=> $HEADERS{$a} } keys %HEADERS;
		my $regexp = $regexps[0];
		if( $HEADERS{$regexp} > 3 ) {
			my $c = $doc =~ s/(?:\n[\r[:blank:]]*){2}(?:$regexp)(?:\n[\r[:blank:]]*){3}/\f/sg;
#			warn "Applying regexp: $regexp ($HEADERS{$regexp} original matches) Removed $c header/footers using ($HEADERS{$regexp} original matches): $regexp\n";
		} else {
			warn "Not enough matching header/footers were found ($HEADERS{$regexp} only)";
		}
	} else {
		warn "Header/footers not found - flying blind if this is a multi-column document";
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
