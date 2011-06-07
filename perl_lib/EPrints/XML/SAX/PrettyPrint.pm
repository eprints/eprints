=head1 NAME

EPrints::XML::SAX::PrettyPrint

=cut

package EPrints::XML::SAX::PrettyPrint;

use strict;

our $AUTOLOAD;

sub new
{
	my( $class, %self ) = @_;

	$self{depth} = 0;

	return bless \%self, $class;
}

sub AUTOLOAD
{
	$AUTOLOAD =~ s/^.*:://;
	return if $AUTOLOAD =~ /^[A-Z]/;
	shift->{Handler}->$AUTOLOAD( @_ );
}

sub start_element
{
	my( $self, $data ) = @_;

	$self->{Handler}->characters({
		Data => "\n" . (" " x ($self->{depth} * 2))
	});

	$self->{depth}++;

	$self->{Handler}->start_element( $data );
}

sub characters
{
	my( $self, $data ) = @_;

	$self->{leaf} = 1;

	$self->{Handler}->characters( $data );
}

sub end_element
{
	my( $self, $data ) = @_;

	$self->{depth}--;

	if( !$self->{leaf} )
	{
		$self->{Handler}->characters({
			Data => "\n" . (" " x ($self->{depth} * 2))
		});
	}
	$self->{leaf} = 0;

	$self->{Handler}->end_element( $data );
}

sub end_document
{
	my( $self, $data ) = @_;

	$self->{Handler}->characters({
		Data => "\n"
	});

	$self->{Handler}->end_document( $data );
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

