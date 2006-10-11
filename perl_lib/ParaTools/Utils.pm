######################################################################
#
# ParaTools::Utils;
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

package ParaTools::Utils;

use 5.006;
use strict;
use warnings;
use LWP::UserAgent;
use File::Temp qw/ tempfile tempdir /;
use URI;

# This hash maps from file extension to a command that can
# convert to plaintext. Replace the source file with _IN_, and
# the destination (plaintext) file with _OUT_.

=pod

=head1 NAME

B<ParaTools::Utils> - handy utility functions

=head1 DESCRIPTION

ParaTools::Utils provides several utility functions for the other
modules.

=head1 METHODS

=over 4

=cut

my %converters =
(
	doc => "wvText _IN_ _OUT_",
	pdf => "pdftotext -raw _IN_ _OUT_",
	ps => "pstotext -output _OUT_ _IN_",
	htm => "links --dump _IN_ > _OUT_",
	html => "links --dump _IN_ > _OUT_",
);

=pod

=item $content = ParaTools::Utils::get_content($location)

This function takes either a filename or a URL as a parameter, and
aims to return a string containing the lines in the file. A hash of
converters is provided in ParaTools/Utils.pm, which should be customised
for your system.

For URLs, the file is first downloaded to a temporary directory, then
converted, whereas local files are copied straight into the temporary
directory. For this reason, some care should be taken when handling very
large files.

=cut

sub get_content
{
	my($location) = @_;

	# Get some temporary files ready.
	my $dir = tempdir( CLEANUP => 1 );
	my (undef, $tofile)  = tempfile(UNLINK => 1, DIR => $dir, SUFFIX => ".txt");

	my $type = "txt";
	my $converter = "";

	# Set up the type. 
	if ($location =~ /\.(\w+?)$/)
	{
		$type = $1;
	}	

	if ($location =~ /^http:\/\//)
	{
		if (!$type)	
		{
			print STDERR "Unknown type - assuming HTML\n";
			$type = "html";
		}
	}
	else
	{
		if (!$type)
		{
			print STDERR "Unknown type - assuming plaintext\n";
			$type = "txt";
		}		
	}

	my (undef, $fromfile) = tempfile(UNLINK => 1, DIR => $dir, SUFFIX => ".$type");

	# Now we know the type, grab the files. 
	if ($location =~ /^http:\/\//)
        {
		# If it's remote, use the LWP mirror function to grab it.
		my $ua = new LWP::UserAgent();
              	$ua->mirror($location, $fromfile);
	}
	else
	{
		# If it's local, mirror it straight to the $fromfile.
		open(FIN, $location);
                open(FOUT, ">$fromfile");
                foreach(<FIN>) { print FOUT $_; }
                close FOUT;
                close FIN;
	}
	
	if ($type ne "txt")
	{
		# Convert from the $fromfile to the $tofile.
		if (!$converters{$type})
		{
			print STDERR "Sorry, no converters available for type $type\n";
			return;
		}
		else
		{
			$converter = $converters{$type};
			$converter =~ s/_IN_/$fromfile/g;
			$converter =~ s/_OUT_/$tofile/g;
		}
		system($converter);
	}
	else
	{
		# If we have text, just use the fromfile.
		$tofile = $fromfile;
	}

	my $content = "";
	open( INPUT, $tofile ) or return;
    	read( INPUT, $content, -s INPUT );
	close INPUT;

	return $content;
}

=pod

=item $escaped_url = ParaTools::Utils::url_escape($string)

Simple function to convert a string into an encoded
URL (i.e. spaces to %20, etc). Takes the unencoded
URL as a parameter, and returns the encoded version.

=cut

sub url_escape
{
        my( $url ) = @_;
	$url =~ s/</%3C/g;
	$url =~ s/>/%3E/g;
	$url =~ s/#/%23/g;
	$url =~ s/;/%3B/g;
	$url =~ s/&/%26/g;
        my $uri = URI->new( $url );
	my $out = $uri->as_string;
        return $out;
}

__END__

=pod

=back

=head1 AUTHOR

Mike Jewell <moj@ecs.soton.ac.uk>

=cut

1;
