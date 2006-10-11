######################################################################
#
# ParaTools::OpenURL;
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

package ParaTools::OpenURL;
use 5.006;
use strict;
use warnings;
use ParaTools::Utils;
my @validtags = ("sid", "id", "genre", "aulast", "aufirst", "auinit", "auinitm", "coden", "issn", "eissn", "isbn", "title", "stitle", "atitle", "volume", "part", "issue", "spage", "epage", "pages", "artnum", "sici", "bici", "ssn", "quarter", "date", "pid", "url", "subject", "year", "month", "day");

=pod

=head1 NAME

B<ParaTools::OpenURL> - OpenURL handling functionality 

=head1 DESCRIPTION

This module contains methods for the parsing and processing
of OpenURLs. Although we have aimed to make it 1.0 compliant,
there may well be errors (please let us know if there are!).

=head1 METHODS

=over 4

=item $openurl_hash = ParaTools::OpenURL::trim_openurl($openurl)

This method takes a hash of OpenURL metadata, and returns a
hash that contains only valid OpenURL fields.

=cut

sub trim_openurl
{
	my($openurl) = @_;
	my $outdata = {};
	foreach(@validtags)
	{
		$outdata->{$_} = $openurl->{$_};
	}
	return $outdata;
}

=pod

=item $openurl_hash = ParaTools::OpenURL::decompose_openurl($openurl)

This method aims to enrich an OpenURL metadata hash
by applying various parsing techniques to the fields.
It decomposes dates into years, months, and days if
possible, fills in the appropriate fields if SICIs are
present, and ensures URLs, ISBNs, etc, are valid. It
returns a pointer to a hash containing the modified 
metadata, and an array of errors (if any).

=cut

sub decompose_openurl
{
	my($openurl) = @_;
	my @errors = ();
	foreach(@validtags)
	{
		if (!$openurl->{$_})
		{
			$openurl->{$_} = undef;
		}
	}
	# Do a little rehashing and validation
	
	# Split up 'date' if present
	
	if ($openurl->{date})
	{
		if ($openurl->{date} =~ /^(\d{4})-(\d{2})-(\d{2})$/)
		{
			$openurl->{year} = $1;
			$openurl->{month} = $2;
			$openurl->{day} = $3;
		}
		elsif ($openurl->{date} =~ /^(\d{4})-(\d{2})$/)
		{
			$openurl->{year} = $1;
			$openurl->{month} = $2;
		}
		elsif ($openurl->{date} =~ /^(\d{4})$/)
		{
			$openurl->{year} = $1;
		}
		else
		{
			push @errors, "Invalid date: ".$openurl->{date};
		}
	
	}

	# Parse SICI and merge with hash
	
	if ($openurl->{sici})
	{
		my %sici = parse_sici($openurl->{sici});
		foreach(("issn", "year", "month", "day"))
		{
			if (!$openurl->{$_} && $sici{$_})
			{
				$openurl->{$_} = $sici{$_};
			}
		}
		if ($sici{locn} && !$openurl->{spage})
		{
			$openurl->{spage} = $sici{locn};
		}
	}

	# 
	
	# Check genre
	
	if ($openurl->{genre})
	{
			if ($openurl->{genre} ne "journal" &&
			$openurl->{genre} ne "book" &&
			$openurl->{genre} ne "conference" &&
			$openurl->{genre} ne "article" &&
			$openurl->{genre} ne "preprint" &&
			$openurl->{genre} ne "proceeding" &&
			$openurl->{genre} ne "bookitem")
		{
			push @errors, "Invalid genre: ".$openurl->{genre};
			delete $openurl->{genre};
		}			
	}

	# Validate issn
	
	if ($openurl->{issn})
	{
		$openurl->{issn} =~ s/-//g;
		if ($openurl->{issn} =~ /^(\d{4})(\d{4})$/)
		{
			$openurl->{issn} = "$1-$2";
		}
		if ($openurl->{issn} !~ /^\d{4}-\d{4}$/)
		{
			push @errors, "Invalid ISSN: ".$openurl->{issn};
			delete $openurl->{issn};
		}
	}
	
	# Validate eissn
	
	if ($openurl->{eissn})
	{
		if ($openurl->{eissn} !~ //)
		{
			push @errors, "Invalid electronic ISSN: ".$openurl->{eissn};
			delete $openurl->{eissn};
		}
	}
	
	# Validate coden
	
	if ($openurl->{coden})
	{
		if ($openurl->{coden} !~ //)
		{
			push @errors, "Invalid CODEN: ".$openurl->{coden};
			delete $openurl->{coden};
		}
	}

	# Validate ISBN
	
	if ($openurl->{isbn})
	{
		$openurl->{isbn} =~ s/-//g; 
		if ($openurl->{isbn} !~ /([\dX]{8})$/)
		{
			push @errors, "Invalid ISBN: ".$openurl->{isbn};
			delete $openurl->{isbn};
		}
		else
		{
			# More complex ISBN check based on Oshiro Naoki's code
			my @isbn = split('', $openurl->{isbn});
			my @tmp = ();
			foreach my $n (@isbn)
			{
				$n = 10 if ($n eq "X");
				push @tmp, $n;
			}
			if (!isbn_check(@tmp))
			{
				push @errors, "Invalid ISBN: ".$openurl->{isbn};
			}
		}
	}

	# Validate BICI
	
	if ($openurl->{bici})
	{
		if ($openurl->{bici} !~ //)
		{
			push @errors, "Invalid BICI: ".$openurl->{bici};
			delete $openurl->{bici};
		}
	}

	# Split up 'pages' if present
	
	if ($openurl->{pages})
	{
		if ($openurl->{pages} =~ /^(\d+)-(\d+)$/)
		{
			$openurl->{spage} = $1;
			$openurl->{epage} = $2;
		}
		else
		{
			push @errors, "Invalid page range: ".$openurl->{pages}
		}
	}
	

	if ($openurl->{ssn} && $openurl->{ssn} !~ /^(winter|spring|summer|fall)$/)
	{
		push @errors, "Invalid season: ".$openurl->{ssn};
		delete $openurl->{ssn};
	}
	
	if ($openurl->{quarter} && $openurl->{quarter} !~ /^[1234]$/)
	{
		push @errors, "Invalid quarter: ".$openurl->{quarter};
		delete $openurl->{quarter};
	}
	if ($openurl->{url} && $openurl->{url} !~ /^(ht|f)tp/)
	{
		$openurl->{url} = "http://".$openurl->{url};
	}
	return ($openurl, @errors);
}

=pod

=item $openurl = ParaTools::OpenURL::create_openurl($metadata)

This method creates and returns an OpenURL from a metadata hash. 
No base URLs are prepended to this, so this should be done before
using it as a link.

=cut

sub create_openurl
{
	my($data) = @_;
	if ($data->{captitle}) { $data->{atitle} = $data->{captitle}; }
	if ($data->{uctitle}) { $data->{atitle} = $data->{uctitle}; }
	($data,undef) = decompose_openurl($data);
	my $openurl = "sid=paracite&";
        my(@openurl_keys) = ("sici", "artnum", "spage", "stitle", "part", "date", "aufirst", "pid", "aulast", "auinitm", "volume", "quarter", "issue", "title", "pages", "ssn", "auinit", "sid", "genre", "eissn", "atitle", "id", "isbn", "bici", "issn", "epage", "coden", "url", "subject", "year", "month", "day");
	my %data_hash = %$data;
        foreach my $key (@openurl_keys)
        {
                if ($data_hash{$key})
                {
                        if (ref $data_hash{$key} eq "ARRAY")
                        {
                                foreach my $el (@{$data_hash{$key}})
                                {
					$el =~ s/[ ]+/ /g;
                                        $openurl .= "$key=".ParaTools::Utils::url_escape($el)."&";
                                }
                        }
                        else
                        {
				$data_hash{$key} =~ s/[ ]+/ /g;
                                $openurl .= "$key=".ParaTools::Utils::url_escape($data_hash{$key})."&";
                        }
                }
        }

        chop $openurl;
	return $openurl;
}

=pod

=item $valid_isbn = ParaTools::OpenURL::isbn_check(@isbn_chars)

This is a simple function that takes an array of ISBN characters, and returns true if it is a valid ISBN.

=cut

sub isbn_check
{
	my(@isbn)=@_;
	my $i;

	for ($i=0; $i<$#isbn; $i++) {
		$isbn[$i+1]+=$isbn[$i];
	}

	for ($i=0; $i<$#isbn; $i++) {
		$isbn[$i+1]+=$isbn[$i];
	}

	return (($isbn[$#isbn]%11)==0);
}

=pod

=item $sici_hash = ParaTools::OpenURL::parse_sici($sici)

This function takes a SICI string, and returns
a hash of information parsed from it, including
date information, issn numbers, etc.

=cut

sub parse_sici
{
	my($sici) = @_;
	my %out = ();
	($out{item}, $out{contrib}, $out{control}) = ($sici =~ /^(.*)<(.*)>(.*)$/);
	($out{issn}, $out{chron}, $out{enum}) = ($out{item} =~ /^(\d{4}-\d{4})\((.+)\)(.+)/);
	($out{site}, $out{title}, $out{locn}) = (split ":", $out{contrib});
	($out{csi}, $out{dpi}, $out{mfi}, $out{version}, $out{check}) = ($out{control} =~ /^(.+)\.(.+)\.(.+);(.+)-(.+)$/); 
	($out{year}, $out{month}, $out{day}, $out{seryear}, $out{seryear}, $out{sermonth}, $out{serday}) = ($out{chron} =~ /^(\d{4})?(\d{2})?(\d{2})?(\/(\d{4})?(\d{2})?(\d{2})?)?/);
	$out{enum} = [split ":", $out{enum}];
	return %out;
}

=pod

=item $bici_hash = ParaTools::OpenURL::parse_bici($bici)

This is not yet implemented, but will eventually
be the BICI alternative for parse_sici.

=cut

sub parse_bici
{
	my($bici) = @_;
	
	my %out = ();
	return %out;
}

1;

__END__

=pod

=back

=head1 AUTHOR

Mike Jewell <moj@ecs.soton.ac.uk>

=cut
