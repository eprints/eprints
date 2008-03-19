######################################################################
#
# EPrints::MetaField::Url;
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

B<EPrints::MetaField::Url> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Url;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;


sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $text = $session->make_text( $value );

	return $text if( $self->{render_dont_link} );

	my $a = $session->render_link( $value );
	$a->appendChild( $text );
	return $a;
}

sub get_xml_schema_type
{
	return "xs:anyURI";
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	return $session->make_doc_fragment;
}

######################################################################
1;
