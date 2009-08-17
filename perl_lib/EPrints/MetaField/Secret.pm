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

sub get_property_defaults
{
	return (
		shift->SUPER::get_property_defaults,
		repeat_secret => $EPrints::MetaField::FROM_CONFIG,
	);
}

sub get_sql_index
{
	my( $self ) = @_;

	return ();
}

sub render_value
{
	my( $self, $handle, $value, $alllangs, $nolink ) = @_;

	if( defined $self->{render_value} )
	{
		return $self->call_property( "render_value",
			$handle, 
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
		return $self->SUPER::render_value( $handle, $value, $alllangs, $nolink );
	}

	return $self->render_single_value( $handle, $value, $nolink );
}

sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	return $handle->html_phrase( 'lib/metafield/secret:show_value' );
}

sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	my $maxlength = $self->get_property( "maxlength" );
	my $size = $self->{input_cols};
	my $password = $handle->render_noenter_input_field(
		class => "ep_form_text",
		type => "password",
		name => $basename,
		id => $basename,
		size => $size,
		maxlength => $maxlength );

	if( !$self->get_property( "repeat_secret" ) )
	{
		return [ [ { el=>$password } ] ];
	}

	my $confirm = $handle->render_noenter_input_field(
		class => "ep_form_text",
		type => "password",
		name => $basename."_confirm",
		id => $basename."_confirm",
		size => $size,
		maxlength => $maxlength );

	my $label1 = $handle->make_element( "div", style=>"margin-right: 4px;" );
	$label1->appendChild( $handle->html_phrase(
		$self->{dataset}->confid."_fieldname_".$self->get_name
	) );
	$label1->appendChild( $handle->make_text( ":" ) );
	my $label2 = $handle->make_element( "div", style=>"margin-right: 4px;" );
	$label2->appendChild( $handle->html_phrase(
		$self->{dataset}->confid."_fieldname_".$self->get_name."_confirm"
	) );
	$label2->appendChild( $handle->make_text( ":" ) );
	
	return [
		[ { el=>$label1 }, { el=>$password } ],
		[ { el=>$label2 }, { el=>$confirm } ]
	];
}

sub is_browsable
{
	return( 0 );
}


sub from_search_form
{
	my( $self, $handle, $prefix ) = @_;

	$handle->get_repository->log( "Attempt to search a \"secret\" type field." );

	return;
}

sub get_search_group { return 'secret'; }  #!! can't really search secret

# REALLY don't index passwords!
sub get_index_codes
{
	my( $self, $handle, $value ) = @_;

	return( [], [], [] );
}

sub validate
{
	my( $self, $handle, $value, $object ) = @_;

	my @probs = $self->SUPER::validate( $handle, $value, $object );

	if( $self->get_property( "repeat_secret" ) )
	{
		my $basename = $self->get_name;

		my $password = $handle->param( $basename );
		my $confirm = $handle->param( $basename."_confirm" );

		if( !length($password) || $password ne $confirm )
		{
			push @probs, $handle->html_phrase( "validate:secret_mismatch" );
		}
	}

	return @probs;
}

######################################################################

######################################################################
1;
