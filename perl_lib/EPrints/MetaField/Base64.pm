######################################################################
#
# EPrints::MetaField::Base64;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Base64> - Base 64 encoded data

=head1 DESCRIPTION

=over 4

=cut

package EPrints::MetaField::Base64;

use MIME::Base64;

use strict;
use base "EPrints::MetaField::Longtext";

sub to_sax
{
	my( $self, $value, %opts ) = @_;

	# MetaField::Compound relies on testing this specific attribute
	return if defined $self->{parent_name};

	return if !$opts{show_empty} && !EPrints::Utils::is_set( $value );

	my $handler = $opts{Handler};
	my $name = $self->name;

	my $enc_attr = {
		Prefix => '',
		LocalName => 'encoding',
		Name => 'encoding',
		NamespaceURI => '',
		Value => 'base64',
	};

	if( ref($value) eq "ARRAY" )
	{
		$handler->start_element( {
			Prefix => '',
			LocalName => $name,
			Name => $name,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {},
		});

		foreach my $v (@$value)
		{
			$handler->start_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
				Attributes => {
					'{}encoding' => $enc_attr,
				},
			});
			$self->to_sax_basic( $v, %opts );
			$handler->end_element( {
				Prefix => '',
				LocalName => "item",
				Name => "item",
				NamespaceURI => EPrints::Const::EP_NS_DATA,
			});
		}
	}
	else
	{
		$handler->start_element( {
			Prefix => '',
			LocalName => $name,
			Name => $name,
			NamespaceURI => EPrints::Const::EP_NS_DATA,
			Attributes => {
				'{}encoding' => $enc_attr,
			},
		});

		$self->to_sax_basic( $value, %opts );
	}

	$handler->end_element( {
		Prefix => '',
		LocalName => $name,
		Name => $name,
		NamespaceURI => EPrints::Const::EP_NS_DATA,
	});
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

