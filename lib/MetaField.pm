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
 	int        => "\$(name) INT UNSIGNED \$(param)",
 	date       => "\$(name) DATE \$(param)",
 	boolean    => "\$(name) SET('TRUE','FALSE') \$(param)",
 	set        => "\$(name) VARCHAR(255) \$(param)",
 	text       => "\$(name) VARCHAR(255) \$(param)",
 	longtext   => "\$(name) TEXT \$(param)",
 	url        => "\$(name) VARCHAR(255) \$(param)",
 	email      => "\$(name) VARCHAR(255) \$(param)",
 	subject    => "\$(name) VARCHAR(255) \$(param)",
 	username   => "\$(name) VARCHAR(255) \$(param)",
 	pagerange  => "\$(name) VARCHAR(255) \$(param)",
 	year       => "\$(name) INT UNSIGNED \$(param)",
 	eprinttype => "\$(name) VARCHAR(255) \$(param)",
 	name       => "\$(name)_given VARCHAR(255) \$(param), \$(name)_family VARCHAR(255) \$(param)"
 );
 
# Map of INDEXs required if a user wishes a field indexed.
my %TYPE_INDEX =
(
 	INT        => "INDEX(\$(name))",
 	DATE       => "INDEX(\$(name))",
	BOOLEAN    => "INDEX(\$(name))",
 	SET        => "INDEX(\$(name))",
 	TEXT       => "INDEX(\$(name))",
 	LONGTEXT   => "INDEX(\$(name))",
 	URL        => "INDEX(\$(name))",
 	EMAIL      => "INDEX(\$(name))",
 	SUBJECT    => "INDEX(\$(name))",
 	USERNAME   => "INDEX(\$(name))",
 	PAGERANGE  => "INDEX(\$(name))",
 	YEAR       => "INDEX(\$(name))",
 	EPRINTTYPE => "INDEX(\$(name))",
 	NAME       => "INDEX(\$(name)_given), INDEX(\$(name)_family)"
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

	if( $self->{type} eq "longtext" || $self->{type} eq "set" )
	{
		$self->{displaylines} = ( defined $data->{displaylines} ? $data->{displaylines} : 5 );
	}
	if( $self->{type} eq "int" )
	{
		$self->{digits} = ( defined $data->{digits} ? $data->{digits} : 20 );
	}
	if( $self->{type} eq "text" )
	{
		$self->{maxlength} = $data->{maxlength};
	}
	if( $self->{type} eq "set" )
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
	
	return $session->{lang}->phrase( "A:fieldname_".$self->{dataset}->confid()."_".$self->{name} );
}

sub display_help
{
	my( $self, $session ) = @_;
	
	return $session->{lang}->phrase( "H:fieldhelp_".$self->{dataset}->confid()."_".$self->{name} );
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

	my $div = $session->make_element( "DIV" );
	my $type = $self->{type};
	
	if( $type eq "boolean" )
	{
		# Boolean: Popup menu
	
		my $default = ( defined $self->{value} ? "EITHER" : $self->{value} );

		$div->appendChild( 
			$session->make_option_list(
				name => $formname,
				values => \@bool_tags,
				default => ( defined $string ? $string : $bool_tags[0] ),
				labels => \%bool_labels ) );
	}
	elsif( $type eq "longtext" || $type eq "text" || 
		$type eq "name" || $type eq "url"  || $type eq "username" ) 
	{
		# complex text types
		$div->appendChild(
			$session->make_element( "INPUT",
				type => "text",
				name => $formname,
				size => $EPrints::HTMLRender::search_form_width,
				maxlength => $EPrints::HTMLRender::field_max ) );
		$div->appendChild( 
			$session->make_option_list(
				name=>$formname."_srchtype",
				values=>\@text_tags,
				default=>$anyall,
				labels=>\%text_labels ) );
	}
	elsif( $type eq "eprinttype" || $type eq "set" || $type eq "subject" )
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
		
		if( $type eq "subject" )
		{
			# WARNING: passes in {} as a dummy user. May need to change this
			# if the "postability" algorithm checks user info.
			( $tags, $labels ) = EPrints::Subject::get_postable( $session, {} );
		}
		elsif( $type eq "eprinttype" )
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
		$div->appendChild( $session->make_option_list(
			name => $formname,
			values => $tags,
			default => \@defaults,
			size=>( scalar @$tags > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$tags ),
			multiple => "true",
			labels => $labels ) );

		if( $self->{multiple} )
		{
			$div->appendChild( 
				$session->make_option_list(
					name=>$formname."_anyall",
					values=>\@set_tags,
					default=>$anyall,
					labels=>\%set_labels ) );
		}
	}
	elsif( $type eq "int" )
	{
		$div->appendChild(
			$session->make_element( "INPUT",
				name=>$formname,
				default=>$string,
				size=>9,
				maxlength=>100 ) );
	}
	elsif( $type eq "year" )
	{
		$div->appendChild(
			$session->make_element( "INPUT",
				name=>$formname,
				default=>$string,
				size=>9,
				maxlength=>9 ) );
	}
	else
	{
		$session->getSite()->log( "Can't Render: $type" );
	}

	return $div->toString();
}

sub search_help
{
        my( $self, $lang ) = @_;

        return $lang->phrase( "H:help_".$self->{type} );
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

sub get_type
{
	my( $self ) = @_;
	return $self->{type};
}

