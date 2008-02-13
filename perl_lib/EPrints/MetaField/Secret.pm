######################################################################
#
# EPrints::MetaField::Secret;
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

B<EPrints::MetaField::Secret> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Secret;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Text );
}

use EPrints::MetaField::Text;

sub get_sql_index
{
	my( $self ) = @_;

	return ();
}

sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	if( defined $self->{render_value} )
	{
		return $self->call_property( "render_value",
			$session, 
			$self, 
			$value, 
			$alllangs, 
			$nolink );
	}

	# this won't handle anyone doing anything clever like
	# having multiple flags on a secret
	# field. If they do, we'll use a more default render
	# method.

	if( $self->get_property( 'multiple' ) )
	{
		return $self->SUPER::render_value( $session, $value, $alllangs, $nolink );
	}

	return $self->render_single_value( $session, $value, $nolink );
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	return $session->html_phrase( 'lib/metafield/secret:show_value' );
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my $maxlength = $self->get_max_input_size;
	my $size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );
	my $input = $session->render_noenter_input_field(
		class => "ep_form_text",
		type => "password",
		name => $basename,
		id => $basename,
		value => $value,
		size => $size,
		maxlength => $maxlength );

	return [ [ { el=>$input } ] ];
}

sub is_browsable
{
	return( 0 );
}


sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	$session->get_repository->log( "Attempt to search a \"secret\" type field." );

	return;
}

sub get_search_group { return 'secret'; }  #!! can't really search secret

# REALLY don't index passwords!
sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}

######################################################################

######################################################################
1;
