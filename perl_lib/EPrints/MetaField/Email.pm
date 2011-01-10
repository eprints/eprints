######################################################################
#
# EPrints::MetaField::Email;
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

B<EPrints::MetaField::Email> - no description

=head1 DESCRIPTION

Contains an Email address that is linked when rendered.

=over 4

=cut

package EPrints::MetaField::Email;

use EPrints::MetaField::Id;
@ISA = qw( EPrints::MetaField::Id );

use strict;

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
