######################################################################
#
# EPrints Metadata Field class
#
#  Holds information about a metadata field
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

package EPrints::MetaField;

use EPrints::Log;
use EPrints::Database;
use EPrints::Constants;

use strict;

#
# The following is the information about the metadata field. This is the
# format of the terse in-line code version, which should be colon-separated.
# i.e. name:type:arguments:displayname:...
#
#@EPrints::MetaField::FieldInfo =
#(
	#"name",            # The field name, as it appears in the database
	#"type",            # The (EPrints) field type
	#"arguments",       # Arguments, depends on the field type
	#"displayname",     # Displayable (English) name
	#"required",        # 0 if the field is optional, 1 if required
	#"editable",        # 1 if the field is user-editable
	#"visible",         # 1 if the field is publically visible
	#"multiple"         # Is a multiple field
#);


my %TYPE_SQL =
(
 	$FT_INT        => "\$(name) INT UNSIGNED \$(param)",
 	$FT_DATE       => "\$(name) DATE \$(param)",
 	$FT_BOOLEAN    => "\$(name) SET('TRUE','FALSE') \$(param)",
 	$FT_SET        => "\$(name) VARCHAR(255) \$(param)",
 	$FT_TEXT       => "\$(name) VARCHAR(255) \$(param)",
 	$FT_LONGTEXT   => "\$(name) TEXT \$(param)",
 	$FT_URL        => "\$(name) VARCHAR(255) \$(param)",
 	$FT_EMAIL      => "\$(name) VARCHAR(255) \$(param)",
 	$FT_SUBJECT    => "\$(name) VARCHAR(255) \$(param)",
 	$FT_USERNAME   => "\$(name) VARCHAR(255) \$(param)",
 	$FT_PAGERANGE  => "\$(name) VARCHAR(255) \$(param)",
 	$FT_YEAR       => "\$(name) INT UNSIGNED \$(param)",
 	$FT_EPRINTTYPE => "\$(name) VARCHAR(255) \$(param)",
 	$FT_NAME       => "\$(name)_given VARCHAR(255) \$(param), \$(name)_family VARCHAR(255) \$(param)"
 );
 
# Map of INDEXs required if a user wishes a field indexed.
my %TYPE_INDEX =
(
 	$FT_INT        => "INDEX(\$(name))",
 	$FT_DATE       => "INDEX(\$(name))",
	$FT_BOOLEAN    => "INDEX(\$(name))",
 	$FT_SET        => "INDEX(\$(name))",
 	$FT_TEXT       => "INDEX(\$(name))",
 	$FT_LONGTEXT   => "INDEX(\$(name))",
 	$FT_URL        => "INDEX(\$(name))",
 	$FT_EMAIL      => "INDEX(\$(name))",
 	$FT_SUBJECT    => "INDEX(\$(name))",
 	$FT_USERNAME   => "INDEX(\$(name))",
 	$FT_PAGERANGE  => "INDEX(\$(name))",
 	$FT_YEAR       => "INDEX(\$(name))",
 	$FT_EPRINTTYPE => "INDEX(\$(name))",
 	$FT_NAME       => "INDEX(\$(name)_given), INDEX(\$(name)_family)"
);

my %TYPE_NAME =
(
 	$FT_INT        => "int",
 	$FT_DATE       => "date",
	$FT_BOOLEAN    => "boolean",
 	$FT_SET        => "set",
 	$FT_TEXT       => "text",
 	$FT_LONGTEXT   => "longtext",
 	$FT_URL        => "url",
 	$FT_EMAIL      => "email",
 	$FT_SUBJECT    => "subject",
 	$FT_USERNAME   => "username",
 	$FT_PAGERANGE  => "pagerange",
 	$FT_YEAR       => "year",
 	$FT_EPRINTTYPE => "eprinttype",
 	$FT_NAME       => "name" 
);


# The following are worked out from appropriate metadata field types:
#
# \@tags
# \%labels
# $displaylines
# $multiple
# $displaydigits

######################################################################
#
##
# cjg comment?
######################################################################
# name   **required**
# type   **required**
# required # default = no
# editable # default = no
# visible  # default = no
# multiple # default = no
# tableid # for help & name 
# 
# displaylines   # for longtext and set (int)   # default = 5
# digits  # for int  (int)   # default = 20
# options # for set (array)   **required if type**
# maxlength # for something

# note: display name, help and labels for options are not
# defined here as they are lang specific.

sub new
{
	my( $class, $dataset, $data ) = @_;
	
	my $self = {};
	bless $self, $class;

	#if( $_[1] =~ m/[01]:[01]:[01]/ ) { print STDERR "---\n".join("\n",caller())."\n"; die "WRONG KIND OF CALL TO NEW METAFIELD: $_[1]"; } #cjg to debug


	foreach( "name","type" )
	{
		if( !defined $data->{$_} )
		{
	print STDERR EPrints::Log::render_struct( $data );
			die "No $_ defined for field.";	
		}
		$self->{$_} = $data->{$_};
	}
print STDERR "NEW FIELD: $data->{name}\n";
	foreach( "required","editable","visible","multiple" )
	{
		$self->{$_} = ( defined $data->{$_} ? $data->{$_} : 0 );
	}
	$self->{dataset} = $dataset;

	if( $self->{type} == $FT_LONGTEXT || $self->{type} == $FT_SET )
	{
		$self->{displaylines} = ( defined $data->{displaylines} ? $data->{displaylines} : 5 );
	}
	if( $self->{type} == $FT_INT )
	{
		$self->{digits} = ( defined $data->{digits} ? $data->{digits} : 20 );
	}
	if( $self->{type} == $FT_TEXT )
	{
		$self->{maxlength} = $data->{maxlength};
	}
	if( $self->{type} == $FT_SET )
	{
		if( !defined $data->{options} )
		{
			die "NO OPTIONS for FIELD: $data->{name}\n";
		}
		$self->{options} = $data->{options};	
	}

	return( $self );
}


######################################################################
#
# $value = get( $field )
#
#  Get information about the metadata field.
#
######################################################################

sub get
{
	my( $self, $field ) = @_;
	
	return( $self->{$field} );
}


######################################################################
#
# $clone = clone()
#
#  Clone the field, so the clone can be edited without affecting the
#  original. (Exception: the tag and label fields - only the references
#  are copied, not the full array/hash.)
#
######################################################################

sub clone
{
	my( $self ) = @_;

	return EPrints::MetaField->new( $self->{dataset} , $self );
}



######################################################################
#
# ( $year, $month, $day ) = get_date( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

sub get_date
{
	my( $time ) = @_;

	my @date = localtime( $time );
	my $day = $date[3];
	my $month = $date[4]+1;
	my $year = $date[5]+1900;
	
	# Ensure number of digits
	while( length $day < 2 )
	{
		$day = "0".$day;
	}

	while( length $month < 2 )
	{
		$month = "0".$month;
	}

	return( $year, $month, $day );
}


######################################################################
#
# $datestamp = get_datestamp( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#
######################################################################

sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::MetaField::get_date( $time );

	return( $year."-".$month."-".$day );
}


sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = "$_ multilang opts not done";
	}
	return ($self->{options}, \%labels);
}

sub display_name
{
	my( $self, $session ) = @_;
	
	return $session->{lang}->phrase( "A:fieldname_".EPrints::Database::table_string($self->{tableid})."_".$self->{name} );
}

sub display_help
{
	my( $self, $session ) = @_;
	
	return $session->{lang}->phrase( "H:fieldhelp_".EPrints::Database::table_string($self->{tableid})."_".$self->{name} );
}

######################################################################
#
# $html = render_html()
#
#  Return HTML suitable for rendering an input component for this field.
#
######################################################################

sub render_html
{
	my( $self, $session, $formname, $string, $anyall, $match ) = @_;

	my $lang = $session->get_lang();
	my $query = $session->get_query();
	
	my @set_tags = ( "ANY", "ALL" );
	my %set_labels = ( 
		"ANY" => $lang->phrase( "F:set_any" ),
		"ALL" => $lang->phrase( "F:set_all" ) );

	my @text_tags = ( "ALL", "ANY" );
	my %text_labels = ( 
		"ANY" => $lang->phrase( "F:text_any" ),
		"ALL" => $lang->phrase( "F:text_all" ) );

	my @bool_tags = ( "EITHER", "TRUE", "FALSE" );
	my %bool_labels = ( "EITHER" => $lang->phrase( "F:bool_nopref" ),
		            "TRUE"   => $lang->phrase( "F:bool_yes" ),
		            "FALSE"  => $lang->phrase( "F:bool_no" ) );

#EPrints::Log::debug( "SearchField", "rendering field $self->{formname} of type $self->{type}" );

	my $html;
	my $type = $self->{type};
	
	if( $type == $FT_BOOLEAN )
	{
		# Boolean: Popup menu
	
		my $default = ( defined $self->{value} ? "EITHER" : $self->{value} );

		$html = $query->popup_menu(
			-name=>$formname,
			-values=>\@bool_tags,
			-default=>( defined $string ? $string : $bool_tags[0] ),
			-labels=>\%bool_labels );
	}
	elsif( $type == $FT_LONGTEXT || $type == $FT_TEXT || $type == $FT_NAME || 
			$type == $FT_URL ) 
	{
		# complex text types
		$html = $query->textfield(
			-name=>$formname,
			-default=>$string,
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		$html .= $query->popup_menu(
			-name=>$formname."_srchtype",
			-values=>\@text_tags,
			-default=>$anyall,
			-labels=>\%text_labels );
	}
	elsif( $type == $FT_USERNAME )
	{
		my @defaults;
		my $anyall = "ANY";
	
		#cjg HMMMM	
		$html = $query->textfield(
			-name=>$formname,
			-default=>$string,
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		$html .= $query->popup_menu(
			-name=>$formname."_anyall",
			-values=>\@set_tags,
			-default=>$anyall,
			-labels=>\%set_labels );
	}
	elsif( $type == $FT_EPRINTTYPE || $type == $FT_SET || $type == $FT_SUBJECT )
	{
		my @defaults;
		
		# Do we have any values already?
		if( defined $string && $string ne "" )
		{
			@defaults = split /\s/, $string;
		}
		else
		{
			@defaults = ();
		}

		# Make a list of possible values
		my( $tags, $labels );
		
		if( $type == $FT_SUBJECT )
		{
			# WARNING: passes in {} as a dummy user. May need to change this
			# if the "postability" algorithm checks user info.
			( $tags, $labels ) = EPrints::Subject::get_postable( $session, {} );
		}
		elsif( $type == $FT_EPRINTTYPE )
		{
			$tags = $session->{metainfo}->get_types( $TID_EPRINT );
			$labels = $session->{metainfo}->get_type_names( $session, $TID_EPRINT );
		}
		else
		{
			# set
			( $tags, $labels ) = $self->tags_and_labels( $session );
		}
	
		my( $old_tags, $old_labels ) = ( $tags, $labels );

#EPrints::Log::debug( "SearchField", "_add_any_option: $old_tags, $old_labels" );
	
		$tags = [ "NONE" ];
		$labels = { "NONE" => "(Any)" };

		# we have to copy the tags and labels as they are currently
		# references to the origionals. 
	
		push @{$tags}, @{$old_tags};
		foreach (keys %{$old_labels})
		{
			$labels->{$_} = $old_labels->{$_};
		}

		$html = $query->scrolling_list(
			-name=>$formname,
			-values=>$tags,
			-default=>\@defaults,
			-size=>( scalar @$tags > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$tags ),
			-multiple=>"true",
			-labels=>$labels );
		if( $self->{multiple} )
		{
			$html .= $query->popup_menu(
				-name=>$formname."_anyall",
				-values=>\@set_tags,
				-default=>$anyall,
				-labels=>\%set_labels );
		}
	}
	elsif( $type == $FT_INT )
	{
		$html = $query->textfield(
			-name=>$formname,
			-default=>$string,
			-size=>9,
			-maxlength=>100 );
	}
	elsif( $type == $FT_YEAR )
	{
		$html = $query->textfield(
			-name=>$formname,
			-default=>$string,
			-size=>9,
			-maxlength=>9 );
	}
	else
	{
		$session->get_site()->log( "Can't Render: $type" );
	}

	return( $html );
}

sub search_help
{
        my( $self, $lang ) = @_;

        return $lang->phrase( "H:help_".$TYPE_NAME{$self->{type}} );
}

sub get_sql_type
{
        my( $self ) = @_;

        return $TYPE_SQL{$self->{type}};
}

sub get_sql_index
{
        my( $self ) = @_;

        return $TYPE_INDEX{$self->{type}};
}

sub get_name
{
	my( $self ) = @_;
	return $self->{name};
}

