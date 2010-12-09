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

Contains a URL that is turned into a hyperlink when rendered. Same length as a L<EPrints::MetaField::Longtext>.

=over 4

=cut

package EPrints::MetaField::Url;

use EPrints::MetaField::Longtext; # get_sql_type
use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

sub get_sql_type
{
	my( $self, $session ) = @_;

	return $self->EPrints::MetaField::Longtext::get_sql_type( $session );
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $text = $session->make_text( $value );

	return $text if( $self->{render_dont_link} );

	my $link = $session->render_link( $value );
	$link->appendChild( $text );
	return $link;
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
