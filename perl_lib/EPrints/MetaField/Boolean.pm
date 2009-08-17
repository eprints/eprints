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
	my( $self, $handle ) = @_;

	# Could be a 'SET' on MySQL/Postgres
	return $handle->get_database->get_column_type(
		$self->get_sql_name(),
		EPrints::Database::SQL_VARCHAR,
		!$self->get_property( "allow_null" ),
		5, # 'TRUE' or 'FALSE'
		undef,
		$self->get_sql_properties,
	);
}

sub get_index_codes
{
	my( $self, $handle, $value ) = @_;

	return( [], [], [] );
}


sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	return $handle->html_phrase(
		"lib/metafield:".($value eq "TRUE"?"true":"false") );
}


sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	if( $self->{input_style} eq "menu" )
	{
		my @values = qw/ TRUE FALSE /;
		my %labels = (
TRUE=> $handle->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
FALSE=> $handle->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE"),
);
		my $height = 2;
		if( !$self->get_property( "required" ) )
		{
			push @values, "";
			$labels{""} = $handle->phrase( "lib/metafield:unspecified_selection" );
			$height++;
		}
		if( $self->get_property( "input_rows" ) )
		{
			$height = $self->get_property( "input_rows" );
		}
		my %settings = (
			height=>$height,
			values=>\@values,
			labels=>\%labels,
			name=>$basename,
			default=>$value
		);
		return [[{ el=>$handle->render_option_list( %settings ) }]];
	}

	if( $self->{input_style} eq "radio" )
	{
		# render as radio buttons

		my $true = $handle->render_noenter_input_field(
			type => "radio",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $basename,
			value => "TRUE" );
		my $false = $handle->render_noenter_input_field(
			type => "radio",
			checked=>( defined $value && $value eq 
					"FALSE" ? "checked" : undef ),
			name => $basename,
			value => "FALSE" );
		my $f = $handle->make_doc_fragment;
		$f->appendChild( 
			$handle->html_phrase(
				$self->{confid}."_radio_".$self->{name},
				true=>$true,
				false=>$false ) );
		if( !$self->get_property( "required" ) )
		{
			my $div = $handle->make_element( "div" );
			$div->appendChild( 
				$handle->render_noenter_input_field(
					type => "radio",
					checked=>( !EPrints::Utils::is_set($value) ? "checked" : undef ),
					name => $basename,
					value => "" ) );
			$f->appendChild( $div );
			$div->appendChild( $handle->html_phrase( 
				"lib/metafield:unspecified_selection" ) );
		}
		return [[{ el=>$f }]];
	}
			
	# render as checkbox (ugly)
	return [[{ el=>$handle->render_noenter_input_field(
				type => "checkbox",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $basename,
				value => "TRUE" ) }]];
}

sub form_value_basic
{
	my( $self, $handle, $basename ) = @_;
	
	my $form_val = $handle->param( $basename );
	if( 
		$self->{input_style} eq "radio" || 
		$self->{input_style} eq "menu" )
	{
		return if( !defined $form_val );
		return "TRUE" if( $form_val eq "TRUE" );
		return "FALSE" if( $form_val eq "FALSE" );
		return;
	}

	# checkbox can't be NULL.
	return "TRUE" if defined $form_val;
	return "FALSE";
}

sub get_unsorted_values
{
	my( $self, $handle, $dataset, %opts ) = @_;

	return [ "TRUE", "FALSE" ];
}


sub render_search_input
{
	my( $self, $handle, $searchfield ) = @_;
	
	# Boolean: Popup menu

	my @bool_tags = ( "EITHER", "TRUE", "FALSE" );
	my %bool_labels = ( 
"EITHER" => $handle->phrase( "lib/searchfield:bool_nopref" ),
"TRUE"   => $handle->phrase( "lib/searchfield:bool_yes" ),
"FALSE"  => $handle->phrase( "lib/searchfield:bool_no" ) );

	my $value = $searchfield->get_value;	
	return $handle->render_option_list(
		name => $searchfield->get_form_prefix,
		values => \@bool_tags,
		default => ( defined $value ? $value : $bool_tags[0] ),
		labels => \%bool_labels );
}

sub from_search_form
{
	my( $self, $handle, $basename ) = @_;

	my $val = $handle->param( $basename );

	return unless defined $val;

	return( "FALSE" ) if( $val eq "FALSE" );
	return( "TRUE" ) if( $val eq "TRUE" );
	return;
}

sub render_search_description
{
	my( $self, $handle, $sfname, $value, $merge, $match ) = @_;

	if( $value eq "TRUE" )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_true",
			name => $sfname );
	}

	return $handle->html_phrase(
		"lib/searchfield:desc_false",
		name => $sfname );
}


sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
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
	$defaults{input_rows} = $EPrints::MetaField::FROM_CONFIG;
	return %defaults;
}

sub render_xml_schema_type
{
	my( $self, $handle ) = @_;

	my $type = $handle->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $handle->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	foreach my $value (@{$self->get_unsorted_values})
	{
		my $enumeration = $handle->make_element( "xs:enumeration", value => $value );
		$restriction->appendChild( $enumeration );
	}

	return $type;
}

######################################################################
1;
