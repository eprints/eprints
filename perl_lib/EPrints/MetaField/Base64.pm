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
	my( $self, $session, $value, $dataset, %opts ) = @_;

	if( defined $self->{parent_name} )
	{
		return $session->make_doc_fragment;
	}

	my $tag = $session->make_element( $self->get_name, encoding => "base64" );
	if( $self->get_property( "multiple" ) )
	{
		foreach my $single ( @{$value} )
		{
			my $item = $session->make_element( "item" );
			$item->appendChild( $self->to_xml_basic( $session, $single, $dataset, %opts ) );
			$tag->appendChild( $item );
		}
	}
	else
	{
		$tag->appendChild( $self->to_xml_basic( $session, $value, $dataset, %opts ) );
	}

	return $tag;
}

######################################################################
1;
