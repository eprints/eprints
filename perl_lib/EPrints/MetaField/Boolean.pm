######################################################################
#
# EPrints::MetaField::Boolean;
#
######################################################################
#
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
	my( $self, $session ) = @_;

	# Could be a 'SET' on MySQL/Postgres
	return $session->get_database->get_column_type(
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
		my @values = qw/ TRUE FALSE /;
		my %labels = (
TRUE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
FALSE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE"),
);
		my $height = 2;
		if( !$self->get_property( "required" ) )
		{
			push @values, "";
			$labels{""} = $session->phrase( "lib/metafield:unspecified_selection" );
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
		return [[{ el=>$session->render_option_list( %settings ) }]];
	}

	if( $self->{input_style} eq "radio" )
	{
		# render as radio buttons

		my $true = $session->render_noenter_input_field(
			type => "radio",
			checked=>( defined $value && $value eq 
					"TRUE" ? "checked" : undef ),
			name => $basename,
			id => "${basename}_TRUE",
			value => "TRUE" );
		my $false = $session->render_noenter_input_field(
			type => "radio",
			checked=>( defined $value && $value eq 
					"FALSE" ? "checked" : undef ),
			name => $basename,
			id => "${basename}_FALSE",
			value => "FALSE" );
		my $f = $session->make_doc_fragment;
		my $phrase_id = $self->{confid}."_radio_".$self->{name};
		if( !$session->get_lang->has_phrase( $phrase_id ) )
		{
			$phrase_id = "lib/metafield/boolean:default_radio_list";
		}
		$f->appendChild( 
			$session->html_phrase(
				$phrase_id,
				true=>$true,
				false=>$false ) );
		if( !$self->get_property( "required" ) )
		{
			my $div = $session->make_element( "div" );
			$div->appendChild( 
				$session->render_noenter_input_field(
					type => "radio",
					checked=>( !EPrints::Utils::is_set($value) ? "checked" : undef ),
					name => $basename,
					id => "${basename}_UNDEF",
					value => "" ) );
			$f->appendChild( $div );
			$div->appendChild( $session->html_phrase( 
				"lib/metafield:unspecified_selection" ) );
		}
		return [[{ el=>$f }]];
	}
			
	# render as checkbox (ugly)
	return [[{ el=>$session->render_noenter_input_field(
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
	$defaults{input_rows} = $EPrints::MetaField::FROM_CONFIG;
	return %defaults;
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	foreach my $value (@{$self->get_unsorted_values})
	{
		my $enumeration = $session->make_element( "xs:enumeration", value => $value );
		$restriction->appendChild( $enumeration );
	}

	return $type;
}

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

