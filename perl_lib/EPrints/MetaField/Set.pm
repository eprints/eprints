######################################################################
#
# EPrints::MetaField::Set;
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

B<EPrints::MetaField::Set> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Set;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	return $self->render_option( $session , $value );
}

sub set_value
{
	my( $self, $object, $value ) = @_;

	if( $self->get_property( "multiple" ) )
	{
		$value = [] if !defined $value;
		my %seen;
		@$value = grep {
			EPrints::Utils::is_set( $_ ) # multiple values must be defined
			&& !$seen{$_}++ # set values must be unique
		} @$value;
	}

	return $object->set_value_raw( $self->{name}, $value );
}

######################################################################
=pod

=item ( $options , $labels ) = $field->tags_and_labels( $session )

Return a reference to an array of options for this
field, plus an array of UTF-8 encoded labels for these options in the 
current language.

=cut
######################################################################

sub tags_and_labels
{
	my( $self , $session ) = @_;
	my @tags = $self->tags( $session );
	my %labels = ();
	foreach( @tags )
	{
		$labels{$_} = EPrints::Utils::tree_to_utf8( 
			$self->render_option( $session, $_ ) );
	}
	return (\@tags, \%labels);
}

sub tags
{
	my( $self, $session ) = @_;
	EPrints::abort( "no options in tags()" ) if( !defined $self->{options} );
	return @{$self->{options}};
}

######################################################################
=pod

=item $xhtml = $field->render_option( $session, $option )

Return the title of option $option in the language of $session as an 
XHTML DOM object.

=cut
######################################################################

sub render_option
{
	my( $self, $session, $option ) = @_;

	if( defined $self->get_property("render_option") )
	{
		return $self->call_property( "render_option", $session, $option );
	}

	$option = "" if !defined $option;

	my $phrasename = $self->{confid}."_fieldopt_".$self->{name}."_".$option;

	# if the option is empty, and no explicit phrase is defined, print 
	# UNDEFINED rather than an error phrase.
	if( $option eq "" && !$session->get_lang->has_phrase( $phrasename, $session ) )
	{
		$phrasename = "lib/metafield:unspecified";
	}

	return $session->html_phrase( $phrasename );
}


sub render_input_field_actual
{
	my( $self, $session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) = @_;

	my $table = $session->make_element( "table", border=>0, cellpadding=>0, cellspacing=>0, class=>"ep_form_input_grid" );
	my $tr = $session->make_element( "tr" );
	my $td = $session->make_element( "td" );
	$table->appendChild( $tr );
	$tr->appendChild( $td );
	if( $self->get_property( "input_ordered" ) )
	{
		$td->appendChild(  $self->SUPER::render_input_field_actual( 
			$session, $value, $dataset, $staff, $hidden_fields, $obj, $basename ) );
		return $table;
	}

	my $required = $self->get_property( "required" );

	my %settings;
	my $default = $value;
	$default = [ $value ] unless( $self->get_property( "multiple" ) );
	$default = [] if( !defined $value );

	# called as a seperate function because subject does this
	# bit differently, and overrides render_set_input.
	$td->appendChild( $self->render_set_input( $session, $default, $required, $obj, $basename ) );
	return $table;
}

sub input_tags_and_labels
{
	my( $self, $session, $obj ) = @_;

	my @tags = $self->tags( $session );
	if( defined $self->get_property("input_tags") )
	{
		@tags = $self->call_property( "input_tags", $session, $obj );
	}

	my %labels = ();
	foreach( @tags )
	{
		$labels{$_} = EPrints::Utils::tree_to_utf8( 
			$self->render_option( $session, $_ ) );
	}

	return( \@tags, \%labels );
}

# this is only called by the compound renderer
sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my( $tags, $labels ) = $self->input_tags_and_labels( $session, $obj );

	# If it's not multiple and not required there 
	# must be a way to unselect it.
	$tags = [ "", @{$tags} ];
	my $unspec = EPrints::Utils::tree_to_utf8( $self->render_option( $session, undef ) );
	$labels = { ""=>$unspec, %{$labels} };

	return( [ [ { el=>$session->render_option_list(
			values => $tags,
			labels => $labels,
			name => $basename,
			id => $basename,
			default => $value,
			multiple => 0,
			height => 1 ) } ]] );
}

# basic input renderer for "set" type fields
sub render_set_input
{
	my( $self, $session, $default, $required, $obj, $basename ) = @_;

	my( $tags, $labels ) = $self->input_tags_and_labels( $session, $obj );
	
	my $input_style = $self->get_property( "input_style" );

	if( 
		!$self->get_property( "multiple" ) && 
		!$required ) 
	{
		# If it's not multiple and not required there 
		# must be a way to unselect it.
		$tags = [ "", @{$tags} ];
		my $unspec = EPrints::Utils::tree_to_utf8( $self->render_option( $session, undef ) );
		$labels = { ""=>$unspec, %{$labels} };
	}

	if( $input_style eq "short" )
	{
		return( $session->render_option_list(
				values => $tags,
				labels => $labels,
				name => $basename,
				id => $basename,
				default => $default,
				multiple => $self->{multiple},
				height => $self->{input_rows}  ) );
	}


	my( $list );
	if( $input_style eq "long" )
	{
		$list = $session->make_element( "dl", class=>"ep_field_set_long" );
	}	
	else
	{
		$list = $session->make_doc_fragment;
	}
	foreach my $opt ( @{$tags} )
	{
		my $row;
		if( $input_style eq "long" )
		{
			$row = $session->make_element( "dt" );
		}
		else
		{
			$row = $session->make_element( "div" );
		}
		my $label1 = $session->make_element( "label", for=>$basename."_".$opt );
		$row->appendChild( $label1 );
		my $checked = undef;
		my $type = "radio";
		if( $self->{multiple} )
		{
			$type = "checkbox";
			foreach( @{$default} )
			{
				$checked = "checked" if( $_ eq $opt );
			}
		}
		else
		{
			$type = "radio";
			if( defined $default->[0] && $default->[0] eq $opt )
			{
				$checked = "checked";
			}
		}
		$label1->appendChild( $session->render_noenter_input_field(
			type => $type,
			name => $basename,
			id => $basename."_".$opt,
			value => $opt,
			checked => $checked ) );
		$label1->appendChild( $session->make_text( " ".$labels->{$opt} ));
		$list->appendChild( $row );

		next unless( $input_style eq "long" );

		my $dd = $session->make_element( "dd" );
		my $label2 = $session->make_element( "label", for=>$basename."_".$opt );
		$dd->appendChild( $label2 );
		my $phrasename = $self->{confid}."_optdetails_".$self->{name}."_".$opt;
		$label2->appendChild( $session->html_phrase( $phrasename ));
		$list->appendChild( $dd );
	}
	return $list;
}

sub form_value_actual
{
	my( $self, $session, $obj, $basename ) = @_;

	if( $self->get_property( "input_ordered" ) )
	{
		return $self->SUPER::form_value_actual( $session, $obj, $basename );
	}

	my @values = grep {
		$_ ne "-" # for the  ------- in defaults at top
	} $session->param( $basename );

	return $self->get_property( "multiple" ) ? \@values : $values[0];
}

# the ordering for set is NOT the same as for normal
# fields.
sub get_values
{
	my( $self, $session, $dataset, %opts ) = @_;

	my @tags = $self->tags( $session );

	return \@tags;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;
		
	return $self->render_option( $session, $value );
}

sub ordervalue_basic
{
	my( $self , $value , $session , $langid ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	my $label = $self->get_value_label( $session, $value );
	return EPrints::Utils::tree_to_utf8( $label );
}

sub render_search_input
{
	my( $self, $session, $searchfield ) = @_;
	
	my $frag = $session->make_doc_fragment;
	
	$frag->appendChild( $self->render_search_set_input( 
				$session,
				$searchfield ) );

	if( $self->get_property( "multiple" ) )
	{
		my @set_tags = ( "ANY", "ALL" );
		my %set_labels = ( 
			"ANY" => $session->phrase( "lib/searchfield:set_any" ),
			"ALL" => $session->phrase( "lib/searchfield:set_all" ) );


		$frag->appendChild( $session->make_text(" ") );
		$frag->appendChild( 
			$session->render_option_list(
				name=>$searchfield->get_form_prefix."_merge",
				values=>\@set_tags,
				default=>$searchfield->get_merge,
				labels=>\%set_labels ) );
	}

	return $frag;
}

sub render_search_set_input
{
	my( $self, $session, $searchfield ) = @_;

	my $prefix = $searchfield->get_form_prefix;
	my $value = $searchfield->get_value;

	my( $tags, $labels ) = ( [], {} );
	# find all the fields we're searching to get their options
	# too if we need to!
	my @allfields = @{$searchfield->get_fields};
	if( scalar @allfields == 1 )
	{
		( $tags, $labels ) = $self->tags_and_labels( $session );
	}
	else
	{
		my( $t ) = {};
		foreach my $field ( @allfields )
		{
			my ( $t2, $l2 ) = $field->tags_and_labels( $session );
			foreach( @{$t2} ) { $t->{$_}=1; }
			foreach( keys %{$l2} ) { $labels->{$_}=$l2->{$_}; }
		}
		my @tags = keys %{$t};
		$tags = \@tags;
	}

	my $max_rows =  $self->get_property( "search_rows" );

	my $height = scalar @$tags;
	$height = $max_rows if( $height > $max_rows );

	my @defaults = ();;
	# Do we have any values already?
	if( defined $value && $value ne "" )
	{
		@defaults = split /\s/, $value;
	}

	return $session->render_option_list( 
		checkbox => ($self->{search_input_style} eq "checkbox"?1:0),
		name => $prefix,
		default => \@defaults,
		multiple => 1,
		labels => $labels,
		values => $tags,
		height => $height );
}	

sub from_search_form
{
	my( $self, $session, $prefix ) = @_;

	my @vals = ();
	foreach( $session->param( $prefix ) )
	{
		next if m/^\s*$/;
		# ignore the "--------" divider.
		next if m/^-$/;
		push @vals,$_;
	}
		
	return if( scalar @vals == 0 );

#	foreach (@vals)
#	{
#		return if( $_ eq "NONE" );
#	}

	# We have some values. Join them together.
	my $val = join ' ', @vals;

	# ANY or ALL?
	my $merge = $session->param( $prefix."_merge" );
	$merge = "ANY" unless( defined $merge );

        my $match = $session->param( $prefix."_match" );
        $match = "EQ" unless defined( $match );
	
	return( $val, $merge, $match );
}

	
sub render_search_description
{
	my( $self, $session, $sfname, $value, $merge, $match ) = @_;

	my $phraseid;
	if( $merge eq "ANY" )
	{
		$phraseid = "lib/searchfield:desc_any_in";
	}
	else
	{
		$phraseid = "lib/searchfield:desc_all_in";
	}

	my $valuedesc = $session->make_doc_fragment;
	my $max_to_show = $self->get_property( "render_max_search_values" );
	my @list = split( ' ',  $value );
	for( my $i=0; $i<scalar @list; ++$i )
	{
		if( $max_to_show && $i == $max_to_show )
		{
			$valuedesc->appendChild( $session->html_phrase( "lib/searchfield:n_more_values", 
				n => $session->xml->create_text_node( scalar @list - $i ),
				total => $session->xml->create_text_node( scalar @list ) ) );
			last;
		}
		if( $i>0 )
		{
			$valuedesc->appendChild( $session->make_text( ", " ) );
		}
		
		$valuedesc->appendChild( $session->make_text( '"' ) );
		$valuedesc->appendChild(
			$self->get_value_label( $session, $list[$i] ) );
		$valuedesc->appendChild( $session->make_text( '"' ) );
	}

	return $session->html_phrase(
		$phraseid,
		name => $sfname, 
		value => $valuedesc ); 
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

sub get_search_group { return 'set'; }

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = "short";
	$defaults{search_input_style} = "checkbox";
	$defaults{input_rows} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{input_ordered} = 0;
	$defaults{search_rows} = $EPrints::MetaField::FROM_CONFIG;
	$defaults{options} = $EPrints::MetaField::REQUIRED;
	$defaults{input_tags} = $EPrints::MetaField::UNDEF;
	$defaults{render_option} = $EPrints::MetaField::UNDEF;
	$defaults{render_max_search_values} = 5;
	$defaults{text_index} = 0;
	return %defaults;
}

sub get_xml_schema_type
{
	my( $self ) = @_;

	return $self->get_property( "type" ) . "_" . $self->{dataset}->confid . "_" . $self->get_name;
}

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my( $tags, $labels ) = $self->tags_and_labels( $session );

	my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	foreach my $value (@$tags)
	{
		my $enumeration = $session->make_element( "xs:enumeration", value => $value );
		$restriction->appendChild( $enumeration );
		if( defined $labels->{$value} )
		{
			my $annotation = $session->make_element( "xs:annotation" );
			$enumeration->appendChild( $annotation );
			my $documentation = $session->make_element( "xs:documentation" );
			$annotation->appendChild( $documentation );
			$documentation->appendChild( $session->make_text( $labels->{$value} ) );
		}
	}

	return $type;
}

######################################################################
1;
