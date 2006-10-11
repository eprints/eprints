######################################################################
#
# ParaTools::CiteParser; 
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

package ParaTools::CiteParser;
use 5.006;
use strict;
use warnings;
use vars qw($VERSION);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = ( 'parse', 'new' );
$VERSION = "1.00";
=pod

=head1 NAME

B<ParaTools::CiteParser> - citation parsing framework 

=head1 DESCRIPTION

ParaTools::CiteParser provides generic methods for reference parsers. This
class should not be used directly, but rather be overridden by specific
parsers.  Parsers that extend the Parser class must provide at least
the two methods defined here to ensure compatibility.

=head1 METHODS

=over 4

=item $cite_parser = ParaTools::CiteParser-E<gt>new()

The new() method creates a new parser instance. 

=cut

sub new
{
	my($class) = @_;
	my $self = {};
	return bless($self, $class);
}

=pod

=item $metadata = $parser-E<gt>parse($reference)

The parse() method takes a reference and returns the extracted metadata.

=cut

sub parse
{
	my($self, $ref) = @_;
	die "This method should be overridden.\n";
}

1;

__END__

=pod

=back

=head1 AUTHOR

Mike Jewell <moj@ecs.soton.ac.uk>

=cut
