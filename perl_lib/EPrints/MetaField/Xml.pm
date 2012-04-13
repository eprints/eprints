=head1 NAME

B<EPrints::MetaField::Xml> - serialise/deserialise XML fragments

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Xml;

use EPrints::MetaField::Longtext;
@ISA = qw( EPrints::MetaField::Longtext );

use strict;
use warnings;

sub value_from_sql_row
{
	my( $self, $repo, $row ) = @_;

	my $value = shift @$row;

	return undef unless EPrints::Utils::is_set( $value );

	my $doc = eval { $repo->xml->parse_string( "<xml>$value</xml>" ) };

	return $repo->create_text_node( "Error parsing stored XML: $@" )
		if $@;

	my $frag = $repo->xml->create_document_fragment;

	foreach my $node ($doc->documentElement->childNodes)
	{
		$frag->appendChild( 
				$repo->xml->clone( $node )
			);
	}

	return $frag;
}

sub sql_row_from_value
{
	my( $self, $repo, $value ) = @_;

	return undef unless defined $value;

	return $repo->xml->to_string( $value );
}

sub render_value_no_multiple
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	return $session->xml->clone( $value );
}

sub to_sax_basic
{
	my( $self, $value, %opts ) = @_;

	return if !defined $value;

	EPrints::XML::SAX::Generator->new(
			Handler => $opts{Handler}
		)->generate_fragment( $value );
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

