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

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Longtext );
}

use EPrints::MetaField::Longtext;

sub to_xml
{
	my( $self, $handle, $value, $dataset, %opts ) = @_;

	my $tag = $self->SUPER::to_xml( $handle, $value, $dataset, %opts );

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

######################################################################
1;
