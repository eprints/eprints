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
	my( $self ) = @_;

	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{repeat_secret} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{text_index} = 0;
	$defaults{sql_index} = 0;

	return %defaults;
}

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

	my $maxlength = $self->get_property( "maxlength" );
	my $size = $self->{input_cols};
	my $password = $session->render_noenter_input_field(
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

	my $confirm = $session->render_noenter_input_field(
		class => "ep_form_text",
		type => "password",
		name => $basename."_confirm",
		id => $basename."_confirm",
		size => $size,
		maxlength => $maxlength );

	my $label1 = $session->make_element( "div", style=>"margin-right: 4px;" );
	$label1->appendChild( $session->html_phrase(
		$self->{dataset}->confid."_fieldname_".$self->get_name
	) );
	$label1->appendChild( $session->make_text( ":" ) );
	my $label2 = $session->make_element( "div", style=>"margin-right: 4px;" );
	$label2->appendChild( $session->html_phrase(
		$self->{dataset}->confid."_fieldname_".$self->get_name."_confirm"
	) );
	$label2->appendChild( $session->make_text( ":" ) );
	
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

sub validate
{
	my( $self, $session, $value, $object ) = @_;

	my @probs = $self->SUPER::validate( $session, $value, $object );

	if( $self->get_property( "repeat_secret" ) )
	{
		my $basename = $self->get_name;

		my $password = $session->param( $basename );
		my $confirm = $session->param( $basename."_confirm" );

		if( !length($password) || $password ne $confirm )
		{
			push @probs, $session->html_phrase( "validate:secret_mismatch" );
		}
	}

	return @probs;
}

sub to_xml
{
	my( $self, $session, $value, $dataset, %opts ) = @_;

	if( !$opts{show_secrets} )
	{
		return $session->xml->create_document_fragment;
	}

	return $self->SUPER::to_xml( $session, $value, $dataset, %opts );
}

######################################################################

######################################################################
1;
