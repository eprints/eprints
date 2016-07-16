=head1 NAME

EPrints::Plugin::Convert::IndexCodes

=cut

package EPrints::Plugin::Convert::IndexCodes;

use strict;

our @ISA = qw( EPrints::Plugin::Convert );

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Generate index codes";
	$self->{visible} = "api";

	return $self;
}

sub can_convert
{
	my( $self, $doc, $type ) = @_;

	return () unless defined($type) && $type eq "indexcodes";

	my %types = $self->SUPER::can_convert( $doc, "text/plain" );
	return () unless exists($types{"text/plain"});

	return(
		$type => {
			plugin => $self,
		},
	);
}

sub export
{
	my( $self, $dir, $doc, $type ) = @_;

	# Find a plugin to extract text from $doc
	$type = "text/plain";
	my %types = $self->SUPER::can_convert( $doc, $type );
	EPrints::abort( "Can't find text conversion plugin" ) unless exists($types{$type});
	my $plugin = $types{$type}->{"plugin"};

	# Extract the text and read it all into $text (up to 4MB)
	my @files = $plugin->export( $dir, $doc, "text/plain" );

	my $text = "";
	foreach my $file (@files)
	{
		open( my $fh, "<:utf8", "$dir/$file" ) or die "Error opening $dir/$file: $!";
		while( $fh->read( $text, 4096, length($text) ) )
		{
			last if length($text) > 4 * 1024 * 1024;
		}
		close($fh);
		unlink("$dir/$file");
	}

	# Extract the code terms from $text
	my( $codes, $badwords ) = ( [], [] );
	if( $text )
	{
		( $codes, $badwords ) = EPrints::MetaField::Text::_extract_words( $self->{session}, $text );
	}

	return () unless scalar(@$codes);

	# Write out an indexcodes.txt file containing all the terms
	open( my $fh, ">:utf8", "$dir/indexcodes.txt" ) or die "Error opening $dir/indexcodes.txt: $!";
	local $" = "\n";
	print $fh "@$codes";
	close( $fh );

	return( "indexcodes.txt" );
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

