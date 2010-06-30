######################################################################
#
# EPrints::MetaField::Base64;
#
######################################################################
#
#  __COPYRIGHT__
#
# Copyright 2000-2008 University of Southampton. All Rights Reserved.
# 
#  __LICENSE__
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

use EPrints::MetaField::Longtext;
@ISA = qw( EPrints::MetaField::Longtext );

use strict;

sub to_xml
{
	my( $self, $session, $value, $dataset, %opts ) = @_;

	my $tag = $self->SUPER::to_xml( $session, $value, $dataset, %opts );

	if( $self->get_property( "multiple" ) )
	{
		foreach my $node ($tag->getElementsByTagName( "item" ) )
		{
			$node->setAttribute( encoding => "base64" );
		}
	}
	elsif( EPrints::XML::is_dom( $tag, "Element" ) )
	{
		$tag->setAttribute( encoding => "base64" );
	}

	return $tag;
}

sub xml_to_epdata
{
	my( $self, $session, $xml, %opts ) = @_;

	my $value = $self->SUPER::xml_to_epdata( $session, $xml, %opts );
	return if !defined $value;

	if( $xml->hasAttribute( "encoding" ) && $xml->getAttribute( "encoding" ) eq "base64" )
	{
		for(ref($value) eq "ARRAY" ? @$value : $value)
		{
			$_ = MIME::Base64::decode_base64( $_ );
		}
	}

	return $value;
}

######################################################################
1;
