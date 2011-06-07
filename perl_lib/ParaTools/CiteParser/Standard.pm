######################################################################
#
# ParaTools::CiteParser::Standard;
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

package ParaTools::CiteParser::Standard;
require Exporter;
@ISA = ("Exporter", "ParaTools::CiteParser");

use 5.006;
use strict;
use warnings;
use ParaTools::CiteParser::Templates;
our @EXPORT_OK = ( 'parse', 'new' );


=pod

=head1 NAME

B<ParaTools::CiteParser::Standard> - citation parsing functionality

=head1 SYNOPSIS

  use ParaTools::CiteParser::Standard;
  # Parse a simple reference
  $parser = new ParaTools::CiteParser::Standard;
  $metadata = $parser->parse("M. Jewell (2002) Citation Parsing for Beginners. Journal of Madeup References 4(3).");
  print "The title of this article is ".$metadata->{atitle}."\n";

=head1 DESCRIPTION

ParaTools::CiteParser::Standard uses a relatively simple template matching
technique to extract metadata from citations.

The Templates.pm module currently provides almost 400 templates, with
more being added regularly, and the parser returns the metadata in a
form that is easily massaged into OpenURLs (see the ParaTools::OpenURL
module for an even easier way).

=cut


my %factors =
(
	"_AUFIRST_"	=> 0.6,
	"_AULAST_"	=> 0.6,
	"_ISSN_"	=> 0.95, 
	"_AUTHORS_"	=> 0.65,
	"_EDITOR_"	=> 0.6,
	"_DATE_"	=> 0.95,
	"_YEAR_" 	=> 0.8,
	"_SUBTITLE_" 	=> 0.6,
	"_TITLE_" 	=> 0.6,
	"_UCTITLE_" 	=> 0.7,
	"_CAPTITLE_"	=> 0.7,
	"_PUBLICATION_" => 0.65,
	"_PUBLISHER_" 	=> 0.65,
	"_PUBLOC_" 	=> 0.65,
	"_UCPUBLICATION_" => 0.74,
	"_CAPPUBLICATION_"	=> 0.7, 
	"_CHAPTER_" 	=> 0.8,
	"_VOLUME_" 	=> 0.8,
	"_ISSUE_" 	=> 0.8,
	"_PAGES_" 	=> 0.9,
	"_ANY_" 	=> 0.05,
	"_ISBN_"	=> 0.95,
	"_ISSN_"	=> 0.95,
	"_SPAGE_"	=> 0.8,
	"_EPAGE_"	=> 0.8,
	"_URL_"		=> 0.9,
);

=pod

=head1 METHODS

=over 4

=item $parser = ParaTools::CiteParser::Standard-E<gt>new()

The new() method creates a new parser. 

=cut

sub new
{
	my($class) = @_;
	my $self = {};
	return bless($self, $class);
}

=pod

=item $reliability = ParaTools::CiteParser::Standard::get_reliability($template)

The get_reliability method returns a value that acts as an indicator
of the likelihood of a template matching correctly. Fields such as
page ranges, URLs, etc, have high likelihoods (as they follow rigorous
patterns), whereas titles, publications, etc have lower likelihoods.

The method takes a template as a parameter, but you shouldn't really
need to use this method much.

=cut

sub get_reliability
{
	my( $template ) = @_;
	my $reliability = 0;
	foreach(keys %factors)
	{
		if ($template =~ /$_/)
		{
			while($template =~ /$_/)
			{
				$reliability += $factors{$_};
				$template =~ s/$_//;	
			}
		}
	}
	return $reliability;
}

=pod

=item $concreteness = ParaTools::CiteParser::Standard::get_concreteness($template)

As with the get_reliability() method, get_concreteness() takes
a template as a parameter, and returns a numeric indicator. In
this case, it is the number of non-field characters in the template.
The more 'concrete' a template, the higher the probability that
it will match well. For example, '_PUBLICATION_ Vol. _VOLUME_' is
a better match than '_PUBLICATION_ _VOLUME_', as _PUBLICATION_ is
likely to subsume 'Vol.' in the second case.

=cut

sub get_concreteness
{
	my( $template ) = @_;
	my $concreteness = 0;
	foreach(keys %factors)
	{
		$template =~ s/$_//g;
	}	
	return length($template);
}

=pod

=item $string = ParaTools::CiteParser::Standard::strip_spaces(@strings)

This is a helper function to remove spaces from all elements
of an array.

=cut

sub strip_spaces
{	
	my(@bits) = @_;
	foreach(@bits) { s/^[[:space:]]*(.+)[[:space:]]*$/$1/;}
	return @bits;
}

=pod

=item $templates = ParaTools::CiteParser::Standard::get_templates()

Returns the current template list from the ParaTools::CiteParser::Templates
module. Useful for giving status lists.

=cut

sub get_templates
{
	return $ParaTools::CiteParser::Templates::templates;
}

=pod

=item @authors = ParaTools::CiteParser::Standard::handle_authors($string)

This (rather large) function handles the author fields of a reference.
It is not all-inclusive yet, but it is usably accurate. It can handle
author lists that are separated by semicolons, commas, and a few other
delimiters, as well as &, and, and 'et al'.

The method takes an author string as a parameter, and returns an array
of extracted information in the format '{family => $family, given =>
$given}'.

=cut 

sub handle_authors
{
	my($authstr) = @_;
	
	my @authsout = ();
	$authstr =~ s/\bet al\b//;
	# Handle semicolon lists
	if ($authstr =~ /;/)
	{
		my @auths = split /[[:space:]]*;[[:space:]]*/, $authstr;
		foreach(@auths)
		{
			my @bits = split /[,[:space:]]+/;
			@bits = strip_spaces(@bits);
			push @authsout, {family => $bits[0], given => $bits[1]};
		}
	}
	elsif ($authstr =~ /^[[:upper:]\.]+[[:space:]]+[[:alnum:]]/)
	{
		my @bits = split /[[:space:]]+/, $authstr;
		@bits = strip_spaces(@bits);
		my $fam = 0;
		my($family, $given);
		foreach(@bits)
		{
			next if ($_ eq "and" || $_ eq "&" || /^[[:space:]]*$/);
			s/,//g;
			if ($fam)
			{
				$family = $_;
				push @authsout, {family => $family, given => $given};
				$fam = 0;
			}
			else
			{
				$given = $_;
				$fam = 1;
			}
		}
	}
	elsif ($authstr =~ /^.+[[:space:]]+[[:upper:]\.]+/)
	{
		# Foo AJ, Bar PJ
		my $fam = 1;
		my $family = "";
		my $given = "";
		my @bits = split /[[:space:]]+/, $authstr;
		@bits = strip_spaces(@bits);
		foreach(@bits)
		{
			s/[,;\.]//g;
			s/\bet al\b//g;
			s/\band\b//;
			s/\b&\b//;
			next if /^[[:space:]]*$/;
			if ($fam == 1)
			{
				$family = $_;
				$fam = 0;
			}
			else
			{
				$given = $_;
				$fam = 1;
				push @authsout, {family => $family, given => $given};
				
			}
		}
	} 
	elsif ($authstr =~ /^.+,[[:space:]]*.+/ || $authstr =~ /.+\band\b.+/)
	{
		my $fam = 1;
		my $family = "";
		my $given = "";
		my @bits = split /[[:space:]]*,|\band\b|&[[:space:]]*/, $authstr;
		@bits = strip_spaces(@bits);
		foreach(@bits)
		{
			next if /^[[:space:]]*$/;
			if ($fam)
			{
				$family = $_;
				$fam = 0;	
			}
			else
			{
				$given = $_;
				push @authsout, {family => $family, given => $given};
				$fam = 1;
			}
		}
	}
	elsif ($authstr =~ /^[[:alpha:][:space:]]+$/)
	{
		$authstr =~ /^([[:alpha:]]+)[[:space:]]*([[:alpha:]]*)$/;
		my $given = "";
		my $family = "";
		if (defined $1 && defined $2)
		{
			$given = $1;
			$family = $2;
		}
		if (!defined $2 || $2 eq "")
		{
			$family = $1;
			$given = "";
		}
		push @authsout, {family => $family, given => $given};
	}
	elsif( $authstr =~ /[[:word:]]+[[:space:]]+[[:word:]]?[[:space:]]*[[:word:]]+/)
	{
		my @bits = split /[[:space:]]+/, $authstr;
		my $rest = $authstr;
		$rest =~ s/$bits[-1]//;
		push @authsout, {family => $bits[-1], given => $rest};
	}
	else
	{
		
	}
	return @authsout;
}

=pod

=item %metadata = $parser-E<gt>xtract_metadata($reference)

This is the key method in the Standard module, although it is not actually
called directly by users (the 'parse' method provides a wrapper). It takes
a reference, and returns a hashtable representing extracted metadata.

A regular expression map is present in this method to transform '_AUFIRST_',
'_ISSN_', etc, into expressions that should match them. The method then
finds the template which best matches the reference, picking the result that
has the highest concreteness and reliability (see above), and returns the
fields in the hashtable. It also creates the marked-up version, that is
useful for further formatting. 

=cut 

sub extract_metadata
{
	my($self, $ref) = @_;
	# Skip to the first Alpha char
	if ($ref !~ /^[[:digit:]]-X\.]+$/) { $ref =~ s/^[^[:alpha:]]+//; }
	$ref =~ s/[[:space:]\*]+$//;
	$ref =~ s/[[:space:]]{2}[[:space:]]+/ /g;
	$ref =~ s/^[[:space:]\*]*(.+)[[:space:]\*]*$/$1/;
	my %metaout = ();
	$metaout{ref} = $ref;

	$metaout{id} = [];
        # Pull out doi addresses
	if ($ref =~ s/doi:(.+)\b//)
	{
		push @{$metaout{id}}, "doi:$1";
	}	
	if ($ref =~ s/((astro-ph|cond-mat|gr-qc|hep-ex|hep-lat|hep-ph|hep-th|math-th|nucl-ex|nucl-th|physics|quant-ph|math|nlin|cs)\/\d+\b)//)
	{
		push @{$metaout{id}}, "arxiv:$1";
	}
	my @specific_pubs =
	(
		# Put any specific publications in here
	); 
	
	my $spec_pubs = "";
	if (scalar @specific_pubs > 0)
	{
 		$spec_pubs = join("|", @specific_pubs);
		$spec_pubs = "|".$spec_pubs;
	}

	my $initial_match = "(?:\\b[[:alpha:]]\\.|\\b[[:alpha:]]\\b)";	
	my $name_match = "(?:(?:[[:alpha:],;&-]+)\\b)";
	my $conjs = "(?:\\s+und\\s+|\\s+band\\s+|\\s|,|&|;)";

	my %matches =
	(
		"_AUFIRST_"	=> "([[:alpha:]\.]+)",
		"_AULAST_"	=> "([[:alpha:]-]+)",
		"_ISSN_"	=> "([[:digit:]-]+)",
		"_AUTHORS_"	=> "((?:$initial_match|$name_match|$conjs)+?)",
		"_DATE_"	=> "([[:digit:]]{2}/[[:digit:]]{2}/[[:digit]]{2})",
		"_YEAR_" 	=> "([[:digit:]]{4})",
		"_TITLE_" 	=> "(.+?)",
		"_SUBTITLE_" 	=> "(.+)",
		"_CHAPTER_"	=> "([[:digit:]]+)",
		"_UCTITLE_" 	=> "([^[:lower:]]+)",
		"_CAPTITLE_"	=> "([[:upper:]][^[:upper:]]+)",
		"_PUBLICATION_" => "([^0-9\(\);\"']{4,}$spec_pubs)",
		"_PUBLISHER_" => "(.+)",
		"_PUBLOC_" => "(.+)",
		"_EDITOR_" => "([[:alpha:]\\.,;\\s&-]+)",
		"_UCPUBLICATION_" => "([^[:lower:]]+)",
		"_CAPPUBLICATION_"	=> "([[:upper:]][^[:upper:]]+)",
		"_VOLUME_" 	=> "([[:digit:]]+)",
		"_ISSUE_" 	=> "([[:digit:]]+)",
		"_PAGES_" 	=> "([[:digit:]]+-{1,2}[[:digit:]]+?)",
		"_ANY_" 	=> "(.+?)",
		"_ISBN_"	=> "([[:digit:]X-]+)",		
		"_ISSN_"	=> "([[:digit:]X-]+)",		
		"_SPAGE_"	=> "([[:digit:]]+)",
		"_EPAGE_"	=> "([[:digit:]]+)",
		"_URL_"		=> "(((http(s?):\\/\\/(www\\.)?)|(\\bwww\\.)|(ftp:\\/\\/(ftp\\.)?))([-\\w\\.:\\/\\s]+)(\\/|\\.\\S+|#\\w+))",
	);


	my(@newtemplates) = ();
	foreach my $template (@$ParaTools::CiteParser::Templates::templates)
	{
		$_ = $template;
		s/\\/\\\\/g;
		s/\(/\\\(/g;
		s/\)/\\\)/g;
		s/\[/\\\[/g;
		s/\]/\\\]/g;
		s/\./\\\./g;
		s/ /\[\[:space:\]\]+/g;
		s/\?/\\\?/g;
		foreach my $key (keys %matches)
		{
			s/$key/$matches{$key}/g;
		}
		$_ .= "[.]?";
		push @newtemplates,$_;
	}
	my $index = 0;	
	my @vars = ();
	my @matchedvars = ();

	my $curr_conc = 0;
	my $curr_rel = 0;
	my $max_conc = 0;
	my $max_rel = 0;
	my $best_match = "";
	my $best_orig = "";
	foreach my $currtemplate (@newtemplates)
	{
		my $original = $ParaTools::CiteParser::Templates::templates->[$index];
		if ($ref =~ /^$currtemplate$/)
		{
			$curr_rel = get_reliability($original);
			$curr_conc = get_concreteness($original);
			if ($curr_rel > $max_rel)
			{
				$best_match = $currtemplate;
				$best_orig = $original;
				$max_conc = $curr_conc;
				$max_rel = $curr_rel;
			}
			elsif ($curr_rel == $max_rel && $curr_conc > $max_conc)
			{
				$best_match = $currtemplate;
				$best_orig = $original;
				$max_conc = $curr_conc;
				$max_rel = $curr_rel;
			}
		}
		$index++;
	}

	$metaout{match} = $best_orig;
	@vars = ($best_orig =~ /_([A-Z]+)_/g);
	@matchedvars = ($ref =~ /^$best_match$/);

	$index = 0;
	if (scalar @matchedvars > 0)
	{
		foreach(@vars)
		{
			$matchedvars[$index] =~ s/^\s*(.+)\s*$/$1/;
			$metaout{lc $_} = $matchedvars[$index];
			$index++;
		}
	}
	foreach(keys %metaout)
	{
		if (/^uc/)
		{
			my $alt = $_;
			$alt =~ s/^uc//;
			if (!defined $metaout{$alt} || $metaout{$alt} eq "")
			{
				$metaout{$alt} = $metaout{$_};
			}
		}
	}

	# Create a marked-up version 
	my $in_ref = $ref;
	my $in_tmp = $best_orig;
	my $in_tmp2 = $best_orig;
	foreach(keys %metaout)
	{
		next if (!defined $metaout{$_} || $metaout{$_} eq "" || $_ eq "any");
		my $toreplace = "_".(uc $_)."_";
		$in_tmp =~ s/$toreplace/<$_>$metaout{$_}<\/$_>/g;
		$in_tmp2 =~ s/$toreplace/$metaout{$_}/g;
	}

	# Fix any _ANY_s
	$in_tmp2 =~ s/\\/\\\\/g;
	$in_tmp2 =~ s/\(/\\\(/g;
	$in_tmp2 =~ s/\)/\\\)/g;
	$in_tmp2 =~ s/\[/\\\[/g;
	$in_tmp2 =~ s/\]/\\\]/g;
	$in_tmp2 =~ s/\./\\\./g;
	$in_tmp2 =~ s/ /\[\[:space:\]\]+/g;
	$in_tmp2 =~ s/\?/\\\?/g;
	$in_tmp2 =~ s/_ANY_/(.+)/g;
	my(@anys) = ($in_ref =~ /$in_tmp2/g);
	
	foreach(@anys)
	{
		$in_tmp =~ s/_ANY_/<any>$_<\/any>/;
	}
	$metaout{marked} = $in_tmp;
	# Map to OpenURL
	if (defined $metaout{authors})
	{
		$metaout{authors} = [handle_authors($metaout{authors})];
		$metaout{aulast} = $metaout{authors}[0]->{family};
		$metaout{aufirst} = $metaout{authors}[0]->{given};
	}
	if (defined $metaout{publisher} && !defined $metaout{publication})
	{
		$metaout{genre} = "book";
	}
	$metaout{atitle} = $metaout{title};	
	$metaout{title} = $metaout{publication};
	if (defined $metaout{cappublication}) { $metaout{title} = $metaout{cappublication} };
	$metaout{date} = $metaout{year};
	return %metaout;

}

=pod

=item $metadata = $parser-E<gt>parse($reference);

This method provides a wrapper to the extract_metadata
function. Simply pass a reference string, and a metadata
hash is returned.

=cut

sub parse
{
	my($self, $ref) = @_;
	my $hashout = {$self->extract_metadata($ref)};
	return $hashout;
}

1;

__END__


=pod

=back

=head1 NOTES

The parser provided should not be seen as exhaustive. As new techniques
are implemented, further modules will be released.

=head1 AUTHOR

Mike Jewell <moj@ecs.soton.ac.uk>

=cut
