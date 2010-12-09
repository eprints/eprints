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

not done

=over 4

=cut

package EPrints::MetaField::Email;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Id );
}

use EPrints::MetaField::Id;

sub render_single_value
{
	my( $self, $session, $value ) = @_;
	
	my $text = $session->make_text( $value );

	return $text if !defined $value;
	return $text if( $self->{render_dont_link} );

	my $a = $session->render_link( "mailto:".$value );
	$a->appendChild( $text );
	return $a;
}

sub render_search_value
{
       my( $self, $session, $value ) = @_;

       my $valuedesc = $session->make_doc_fragment;
       $valuedesc->appendChild( $session->make_text( '"' ) );
       $valuedesc->appendChild( $session->make_text( $value ) );
       $valuedesc->appendChild( $session->make_text( '"' ) );

       return $valuedesc;
}

######################################################################
1;
