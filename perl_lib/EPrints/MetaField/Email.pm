######################################################################
#
# EPrints::MetaField::Email;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

Contains an Email address that is linked when rendered.

=over 4

=cut

package EPrints::MetaField::Email;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

sub form_value_basic
{
	my $self = shift;
	my $v = $self->SUPER::form_value_basic( @_ );
	return unless( defined $v );
	# strip leading and trailing whitespace
	$v =~ s/^\s+|\s+$//g;
	return $v;
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;
	
	return $session->make_doc_fragment if !EPrints::Utils::is_set( $value );

	my $text = $session->make_text( $value );

	return $text if !defined $value;
	return $text if( $self->{render_dont_link} );

	my $link = $session->render_link( "mailto:".$value );
	$link->appendChild( $text );
	return $link;
}

######################################################################
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

