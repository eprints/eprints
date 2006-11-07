######################################################################
#
# EPrints::MetaField::Boolean;
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

B<EPrints::MetaField::Boolean> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Boolean;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;


sub get_sql_type
{
	my( $self, $notnull ) = @_;

	return $self->get_sql_name()." SET('TRUE','FALSE')".($notnull?" NOT NULL":"");
}

sub get_index_codes
{
	my( $self, $session, $value ) = @_;

	return( [], [], [] );
}


sub render_single_value
{
	my( $self, $session, $value ) = @_;

	return $session->html_phrase(
		"lib/metafield:".($value eq "TRUE"?"true":"false") );
}


sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	if( $self->{input_style} eq "menu" )
	{
		my %settings = (
			height=>2,
			values=>[ "TRUE", "FALSE" ],
			labels=>{
TRUE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
FALSE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE")
			},
			name=>$basename,
			default=>$value
		);
		return [[{ el=>$session->render_option_list( %settings ) }]];
	}

	if( $self->{input_style} eq "radio" )
	{
		# render as radio buttons

		my $true = $session->render_input_field(
			type => "radio",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $basename,
			value => "TRUE" );
		my $false = $session->render_input_field(
			type => "radio",
			checked=>( defined $value && $value ne 
					"TRUE" ? "checked" : undef ),
			name => $basename,
			value => "FALSE" );
		return [[{ el=>$session->html_phrase(
			$self->{confid}."_radio_".$self->{name},
			true=>$true,
			false=>$false ) }]];
	}
			
	# render as checkbox (ugly)
	return [[{ el=>$session->render_input_field(
				type => "checkbox",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $basename,
				value => "TRUE" ) }]];
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	my $form_val = $session->param( $basename );
	my $true = 0;
	if( 
		$self->{input_style} eq "radio" || 
		$self->{input_style} eq "menu" )
	{
			$true = (defined $form_val && $form_val eq "TRUE");
	}
	else
	{
		$true = defined $form_val;
	}
	return ( $true ? "TRUE" : "FALSE" );
}

sub get_unsorted_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	return [ "TRUE", "FALSE" ];
}


sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	# Boolean: Popup menu

	my @bool_tags = ( "EITHER", "TRUE", "FALSE" );
	my %bool_labels = ( 
"EITHER" => $session->phrase( "lib/searchfield:bool_nopref" ),
"TRUE"   => $session->phrase( "lib/searchfield:bool_yes" ),
"FALSE"  => $session->phrase( "lib/searchfield:bool_no" ) );

	my $value = $searchfield->get_value;	
	return $session->render_option_list(
		name => $searchfield->get_form_prefix,
		values => \@bool_tags,
		default => ( defined $value ? $value : $bool_tags[0] ),
		labels => \%bool_labels );
}

sub from_search_form
{
	my( $self, $session, $basename ) = @_;

	my $val = $session->param( $basename );

	return unless defined $val;

	return( "FALSE" ) if( $val eq "FALSE" );
	return( "TRUE" ) if( $val eq "TRUE" );
	return;
}

sub render_search_description
{
	my( $self, $session, $sfname, $value, $merge, $match ) = @_;

	if( $value eq "TRUE" )
	{
		return $session->html_phrase(
			"lib/searchfield:desc_true",
			name => $sfname );
	}

	return $session->html_phrase(
		"lib/searchfield:desc_false",
		name => $sfname );
}


sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	return EPrints::Search::Condition->new( 
		'=', 
		$dataset,
		$self, 
		$search_value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = 0;
	$defaults{text_index} = 0;
	return %defaults;
}

######################################################################
1;
