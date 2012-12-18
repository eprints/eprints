######################################################################
#
# EPrints::Page
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::Page> - A Webpage 

=head1 DESCRIPTION

This class describes a webpage suitable for serving via mod_perl or writing to a file.

Supported pins:

=over 4

=item title

=item title.textonly

=item page

=item head

=item template

=back

=head1 METHODS

=over 4

=cut

package EPrints::Page;

use strict;

=item $page = EPrints::Page->new( %options )

=cut

sub new
{
	my( $class, %self ) = @_;

	$self{pins} = {} if !exists $self{pins};

	return bless \%self, $class;
}

=item $page = EPrints::Page->new_from_file( $prefix, %options )

Read pins from $prefix on disk.

=cut

sub new_from_file
{
	my( $class, $prefix, %params ) = @_;

	my $self = $class->new( %params );

	foreach my $pinid (qw( title title.textonly page head template ))
	{
		local $/;
		open(my $fh, "<:utf8", "$prefix.$pinid") or next;
		$self->{pins}{"utf-8.$pinid"} = <$fh>;
		close($fh);
		chomp($self->{pins}{"utf-8.$pinid"}); # remove trailing newline
	}

	return $self;
}

=item $pins = $page->pins()

Returns the plain-text pins in this page.

=cut

sub pins { shift->{pins} }

=item $utf8 = $page->utf8_pin( $pinid )

Returns the pin identified by $pinid as serialised xhtml.

=cut

sub utf8_pin
{
	my( $self, $pinid ) = @_;

	if( exists $self->{pins}{$pinid} )
	{
		return $self->{repository}->xhtml->to_xhtml( $self->{pins}{$pinid} );
	}
	elsif( exists $self->{pins}{"utf-8.$pinid"} )
	{
		return $self->{pins}{"utf-8.$pinid"};
	}
	else
	{
		return "";
	}
}

=item $text = $page->text_pin( $pinid )

Returns the pin identified by $pinid as plain text.

=cut

sub text_pin
{
	my( $self, $pinid ) = @_;

	if( exists $self->{pins}{"utf-8.$pinid.textonly"} )
	{
		return $self->{pins}{"utf-8.$pinid.textonly"};
	}
	elsif( exists $self->{pins}{$pinid} )
	{
		return $self->{repository}->xhtml->to_text_dump( $self->{pins}{$pinid},
				show_links => 0,
			);
	}
	elsif( exists $self->{pins}{"utf-8.$pinid"} )
	{
		return $self->{pins}{"utf-8.$pinid"};
	}
	else
	{
		return "";
	}
}

=item @files = $page->write_to_file( $prefix )

Write the pins to files prefixed by $prefix, where each pin will be written as "$prefix.{pinname}".

Returns the list of files written (full path).

=cut

sub write_to_file
{
	my( $self, $prefix ) = @_;

	my @r;

	my $dir = $prefix;
	$dir =~ s{[^/]+$}{};
	EPrints->system->mkdir( $dir );

	foreach my $pinid (qw( title title.textonly page head template ))
	{
		my $pin = $self->utf8_pin( $pinid );
		next if $pin eq "";

		open(my $fh, ">:utf8", "$prefix.$pinid") or die "Error writing to $prefix.$pinid: $!";
		print $fh $pin;
		close($fh);
		push @r, "$prefix.$pinid";
	}

	return @r;
}

1;


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2012 University of Southampton.

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

