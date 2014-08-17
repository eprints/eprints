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

sub form_value 
{
  my ($self, $session, $object, $prefix) = @_;

  my $basename = $self->basename($prefix);

  my $value = $self->form_value_actual($session, $object, $basename);

  if(ref $value eq "ARRAY") 
  {
    foreach my $v (@{$value}) 
    {
      $v = MIME::Base64::encode_base64($v);
    }
  } 
  else 
  {
    $value = MIME::Base64::encode_base64($value);
  }

  return $value;
}

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

sub get_xml_schema_type
{
    my ( $self ) = @_;

    return $self->get_property( "type" ) . "_" . $self->{dataset}->confid . "_" . $self->get_name;
}

sub render_xml_schema_type
{
    my ( $self, $session ) = @_;

    # Returns DOM for the following:
    # <xs:complexType name="base64_file_data">
    #   <xs:simpleContent>
    #     <xs:extension base="xs:base64Binary">
    #       <xs:attribute name="encoding">
    #         <xs:simpleType>
    #           <xs:restriction base="xs:string">
    #             <xs:enumeration value="base64" />
    #           </xs:restriction>
    #         </xs:simpleType>
    #       </xs:attribute>
    #     </xs:extension>
    #   </xs:simpleContent>
    # </xs:complexType>

    my $type = $session->make_element( 'xs:complexType',
                                       name => $self->get_xml_schema_type );
    my $sc = $session->make_element( 'xs:simpleContent' );
    my $ext =
      $session->make_element( 'xs:extension', base => 'xs:base64Binary' );

    # encoding attribute
    my $encoding = $session->make_element( 'xs:attribute', name => 'encoding' );
    my $enc_type = $session->make_element( 'xs:simpleType' );
    my $enc_restr =
      $session->make_element( 'xs:restriction', base => 'xs:string' );
    my $enc_enum =
      $session->make_element( 'xs:enumeration', value => 'base64' );

    $enc_restr->appendChild( $enc_enum );
    $enc_type->appendChild( $enc_restr );
    $encoding->appendChild( $enc_type );
    $ext->appendChild( $encoding );
    $sc->appendChild( $ext );
    $type->appendChild( $sc );

    return $type;
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

