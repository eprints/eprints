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

use strict;

# Months
my @monthkeys = ( "00",
               "01",
               "02",
               "03",
               "04",
               "05",
               "06",
               "07",
               "08",
               "09",
               "10",
               "11",
               "12" );

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
 	int        => "INDEX(\$(name))",
 	date       => "INDEX(\$(name))",
	boolean    => "INDEX(\$(name))",
 	set        => "INDEX(\$(name))",
 	text       => "INDEX(\$(name))",
 	longtext   => "INDEX(\$(name))",
 	url        => "INDEX(\$(name))",
 	email      => "INDEX(\$(name))",
 	subject    => "INDEX(\$(name))",
 	username   => "INDEX(\$(name))",
 	pagerange  => "INDEX(\$(name))",
 	year       => "INDEX(\$(name))",
 	eprinttype => "INDEX(\$(name))",
 	name       => "INDEX(\$(name)_given), INDEX(\$(name)_family)"
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

## WP1: BAD
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
			die "No $_ defined for field. (".join(",",caller()).")";	
		}
		$self->{$_} = $data->{$_};
	}
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

## WP1: BAD
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

## WP1: BAD
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

## WP1: BAD
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

## WP1: BAD
sub get_datestamp
{
	my( $time ) = @_;

	my( $year, $month, $day ) = EPrints::MetaField::get_date( $time );

	return( $year."-".$month."-".$day );
}


## WP1: BAD
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

## WP1: BAD
sub display_name
{
	my( $self, $session ) = @_;
	
	return $session->phrase( "fieldname_".$self->{dataset}->confid()."_".$self->{name} );
}

## WP1: BAD
sub display_help
{
	my( $self, $session ) = @_;
	
	return $session->phrase( "fieldhelp_".$self->{dataset}->confid."_".$self->{name} );
}

## WP1: BAD
sub getSQLType
{
        my( $self , $notnull ) = @_;

	my $type = $TYPE_SQL{$self->{type}};

	$type =~ s/\$\(name\)/$self->{name}/g;
	if( $notnull )
	{
		$type =~ s/\$\(param\)/NOT NULL/g;
	}
	else
	{
		$type =~ s/\$\(param\)//g;
	}

	return $type;
}

## WP1: BAD
sub getSQLIndex
{
        my( $self ) = @_;

	my $index = $TYPE_INDEX{$self->{type}};
	$index =~ s/\$\(name\)/$self->{name}/g;
print STDERR "gsind: $self->{type}...($index)\n";
	return $index;
}

## WP1: BAD
sub getName
{
	my( $self ) = @_;
	return $self->{name};
}

## WP1: BAD
sub get_type
{
	my( $self ) = @_;
	return $self->{type};
}

## WP1: GOOD
sub isEditable
{
	my( $self ) = @_;
	return $self->{editable};
}

## WP1: GOOD
sub setEditable
{
	my( $self , $val ) = @_;
	$self->{editable} = $val;
}
## WP1: GOOD
sub isRequired
{
	my( $self ) = @_;
	return $self->{required};
}

## WP1: GOOD
sub setRequired
{
	my( $self , $val ) = @_;
	$self->{required} = $val;
}

## WP1: BAD
sub isMultiple
{
	my( $self ) = @_;
	return $self->{multiple};
}
## WP1: BAD
sub setMultiple
{
	my( $self , $val ) = @_;
	$self->{multiple} = $val;
}

## WP1: BAD
sub isIndexed
{
	my( $self ) = @_;
	return $self->{indexed};
}
## WP1: BAD
sub setIndexed
{
	my( $self , $val ) = @_;
	$self->{indexed} = $val;
}
## WP1: BAD
sub is_type
{
	my( $self , @typenames ) = @_;

	foreach( @typenames )
	{
		return 1 if( $self->{type} eq $_ );
	}
	return 0;
}

## WP1: BAD
sub isTextIndexable
{
	my( $self ) = @_;
	return $self->is_type( "text","longtext","url","email" );
}

######################################################################
#
# $html = getHTML( $field, $value )
#
#  format a field. Returns the formatted HTML as a string (doesn't
#  actually print it.)
#
######################################################################

## WP1: BAD
sub getHTML
{
	my( $self, $session, $value ) = @_;
#cjg not DOM


	if( !defined $value || $value eq "" )
	{
		return $session->makeText( "" );
	}

	my $html;

	if( $self->is_type( "text" , "int" , "pagerange" , "year" ) )
	{
		# Render text
		return $session->makeText( $value );
	}

	if( $self->is_type( "name" ) )
	{
		return $session->makeText(
			EPrints::Name::format_names( $value ) );
	}

	if( $self->is_type( "eprinttype" ) )
	{
		$html = $self->{labels}->{$value} if( defined $value );
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
		$html = ( $value eq "TRUE" ? "Yes" : "No" ) if( defined $value );
	}
	elsif( $self->is_type( "longtext" ) )
	{
		$html = ( defined $value ? $value : "" );
		$html =~ s/\r?\n\r?\n/<BR><BR>\n/s;
	}
	elsif( $self->is_type( "date" ) )
	{
		if( defined $value )
		{
			my @elements = split /\-/, $value;

			if( $elements[0]==0 )
			{
				$html = "UNSPECIFIED";
			}
			elsif( $#elements != 2 || $elements[1] < 1 || $elements[1] > 12 )
			{
				$html = "INVALID";
			}
			else
			{
#				$html = $elements[2]." ".$monthnames{$elements[1]}." ".$elements[0];
			}
		}
		else
		{
			$html = "UNSPECIFIED";
		}
	}
	elsif( $self->is_type( "url" ) )
	{
		$html = "<A HREF=\"$value\">$value</A>" if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->is_type( "email" ) )
	{
		$html = "<A HREF=\"mailto:$value\">$value</A>"if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->is_type( "subject" ) )
	{
		$html = "";

		my $subject_list = EPrints::SubjectList->new( $value );
		my @subjects = $subject_list->get_tags();
		
		my $sub;
		my $first = 0;

		foreach $sub (@subjects)
		{
			if( $first==0 )
			{
				$first = 1;
			}
			else
			{
				$html .= "<BR>";
			}
			
			$html .= EPrints::Subject::subject_label( $self->{session}, $sub );
		}
	}
	elsif( $self->is_type( "set" ) )
	{
		$html = "";
		my @setvalues;
		@setvalues = split /:/, $value if( defined $value );
		my $first = 0;

		foreach (@setvalues)
		{
			if( $_ ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
				$html .= $self->{labels}->{$_};
			}
		}
	}
	elsif( $self->is_type( "username" ) )
	{
		$html = "";
		my @usernames;
		@usernames = split /:/, $value if( defined $value );
		my $first = 0;

		foreach (@usernames)
		{
			if( $_ ne "" )
			{
				$html .=  ", " unless( $first );
				$first=1 if( $first );
				$html .= $_;
				# This could be much prettier
			}
		}
	}
	
	$session->getSite()->log( "Unknown field type: ".$self->{type} );
	return undef;

}


## WP1: BAD
sub render_input_field
{
	my( $self, $session, $value ) = @_;

	my( $html, $frag );

	$html = $session->makeDocFragment();

	$frag = $html;

	my $boxcount = 2;

	if( $self->is_type( "name" ) )
	{
		my( $table, $tr, $th, $div );
		$table = $session->make_element( 
					"table", 
					cellpadding=>0,
					cellspacing=>2,
					border=>0 );
		$tr = $session->make_element( "tr" );
		$th = $session->make_element( "th" );
		$div = $session->make_element( "div", class => "namefieldheading" );
		$div->appendChild( $session->html_phrase( "family_name" ) );
		$th->appendChild( $div );
		$tr->appendChild( $th );
		$th = $session->make_element( "th" );
		$div = $session->make_element( "div", class => "namefieldheading" );
		$div->appendChild( $session->html_phrase( "first_names" ) );
		$th->appendChild( $div );
		$tr->appendChild( $th );
		$table->appendChild( $tr );
	
		$html->appendChild( $table );
		$frag = $table;
	}

	if( $self->isMultiple() )
	{
		my $i;
		for( $i=1 ; $i<=$boxcount ; ++$i )
		{
			my $morebutton = undef;
			if( $i == $boxcount )
			{
				$morebutton = $session->makeText( "MORE" );
			}
			$frag->appendChild( 
				$self->_render_input_field_aux( 
					$session, 
					$value->[$i], 
					$i,
					$morebutton ) );
		}
	}
	else
	{
		$frag->appendChild( 
			$self->_render_input_field_aux( 
				$session, 
				$value ) );
	}

	return $html;
}


sub _render_input_field_aux
{
	my( $self, $session, $value, $n, $morebutton ) = @_;
print STDERR "val($value)\n";

	my $id_suffix = "";
	$id_suffix = "_$n" if( defined $n );

	# These DO NOT belong here. cjg.
	my( $FORM_WIDTH, $INPUT_MAX ) = ( 60, 255 );

	my $html = $session->makeDocFragment();
	if( 
		$self->is_type( "text" ) ||
		$self->is_type( "url" ) ||
		$self->is_type( "email" ) )
	{
		my $maxlength = ( defined $self->{maxlength} ? 
				$self->{maxlength} : 
				$INPUT_MAX );
		my $size = ( $maxlength > $FORM_WIDTH ?
				$FORM_WIDTH : 
				$maxlength );
		my( $div );
		$div = $session->make_element( "div" );	
		$div->appendChild( $session->make_element(
			"input",
			name => $self->{name}.$id_suffix,
			value => $value,
			size => $size,
			maxlength => $maxlength ) );
		if( defined $morebutton )
		{
			$div->appendChild( $morebutton );
		}
		$html->appendChild( $div );
	}
	elsif( $self->is_type( "longtext" ) )
	{
		my( $div , $textarea );
		$div = $session->make_element( "div" );	
		$textarea = $session->make_element(
			"textarea",
			name => $self->{name}.$id_suffix,
			rows => $self->{displaylines},
			cols => $FORM_WIDTH,
			wrap => "virtual" );
		$textarea->appendChild( $session->makeText( $value ) );
		$div->appendChild( $textarea );
		
		$html->appendChild( $div );
	}
	elsif( $self->is_type( "name" ) )
	{
		my( $tr, $td );
		$tr = $session->make_element( "tr" );
		$td = $session->make_element( "td" );
		$td->appendChild( $session->make_element(
			"input",
			name => $self->{name}.$id_suffix."_familyname",
			value => $value->{familyname},
			size => int( $FORM_WIDTH / 2 ),
			maxlength => $INPUT_MAX ) );
		$tr->appendChild( $td );
		$td = $session->make_element( "td" );
		$td->appendChild( $session->make_element(
			"input",
			name => $self->{name}.$id_suffix."_givenname",
			value => $value->{givenname},
			size => int( $FORM_WIDTH / 2 ),
			maxlength => $INPUT_MAX ) );
		$tr->appendChild( $td );
		if( defined $morebutton )
		{
			$td = $session->make_element( "td" );
			$td->appendChild( $morebutton );
			$tr->appendChild( $td );
		}
		$html->appendChild( $tr );
	}
	elsif( $self->is_type( "date" ) )
	{
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			if( $month == 0 )
			{
				($year, $month, $day) = ("", "00", "");
			}
		}

		$html->appendChild( $session->html_phrase( "year" ) );
		$html->appendChild( $session->makeText(" ") );

		$html->appendChild( $session->make_element(
			"input",
			name => $self->{name}.$id_suffix."_year",
			value => $year,
			size => 4,
			maxlength => 4 ) );

		$html->appendChild( $session->makeText(" ") );
		$html->appendChild( $session->html_phrase( "month" ) );
		$html->appendChild( $session->makeText(" ") );

		$html->appendChild( $session->make_option_list(
			name => $self->{name}.$id_suffix."_month",
			values => \@monthkeys,
			default => $month,
			labels => $self->_month_names( $session ) ) );
print STDERR "(MONTH=$month)\n";
		$html->appendChild( $session->makeText(" ") );
		$html->appendChild( $session->html_phrase( "day" ) );
		$html->appendChild( $session->makeText(" ") );

		$html->appendChild( $session->make_element(
			"input",
			name => $self->{name}.$id_suffix."_day",
			value => $day,
			size => 2,
			maxlength => 2 ) );
	}
	else
	{
		$html->appendChild( $session->makeText( "???" ) );
		$session->getSite()->log( "Don't know how to render input".
					  "field of type: ".$self->get_type() );
	}
	return $html;

my $field = 1;
	
	my $type = $field->{type};

	if( $type eq "text" || $type eq "url" || $type eq "email" )
	{
	}
	elsif( $type eq "int" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>$field->{displaydigits},
		                                   -maxlength=>$field->{displaydigits} );
	}
	elsif( $type eq "boolean" )
	{
		$html = $self->{query}->checkbox(
			-name=>$field->{name},
			-checked=>( defined $value && $value eq "TRUE" ? "checked" : undef ),
			-value=>"TRUE",
			-label=>"" );
	}
	elsif( $type eq "longtext" )
	{
	}
	elsif( $type eq "set" )
	{
		my @actual;
		@actual = split /:/, $value if( defined $value );

		# Get rid of beginning and end empty values
		shift @actual if( defined $actual[0] && $actual[0] eq "" );
		pop @actual if( defined $actual[$#actual] && $actual[$#actual] eq "" );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$field->{tags},
			-default=>\@actual,
			-size=>( $field->{displaylines} ),
			-multiple=>( $field->{multiple} ? 'true' : undef ),
			-labels=>$field->{labels} );
	}
	elsif( $type eq "pagerange" )
	{
		my @pages;
		
		@pages = split /-/, $value if( defined $value );
		
		$html = $self->{query}->textfield( -name=>"$field->{name}_from",
		                                   -default=>$pages[0],
		                                   -size=>6,
		                                   -maxlength=>10 );

		$html .= "&nbsp;to&nbsp;";

		$html .= $self->{query}->textfield( -name=>"$field->{name}_to",
		                                    -default=>$pages[1],
		                                    -size=>6,
		                                    -maxlength=>10 );
	}
	elsif( $type eq "year" )
	{
		$html = $self->{query}->textfield( -name=>$field->{name},
		                                   -default=>$value,
		                                   -size=>4,
		                                   -maxlength=>4 );
	}
	elsif( $type eq "eprinttype" )
	{
		my @eprint_types = $self->{session}->{metainfo}->get_types( "eprint" );
		my $labels = $self->{session}->{metainfo}->get_type_names( $self->{session}, "eprint" );

		my $actual = [ ( !defined $value || $value eq "" ?
			$eprint_types[0] : $value ) ];
		my $height = ( $EPrints::HTMLRender::list_height_max < $#eprint_types+1 ?
		               $EPrints::HTMLRender::list_height_max : $#eprint_types+1 );

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>\@eprint_types,
			-default=>$actual,
			-size=>$height,
			-labels=>$labels );
	}
	elsif( $type eq "subject" )
	{
		my $subject_list = EPrints::SubjectList->new( $value );

		# If in the future more user-specific subject tuning is needed,
		# will need to put the current user in the place of undef.
		my( $sub_tags, $sub_labels );
		
		if( $field->{showall} )
		{
			( $sub_tags, $sub_labels ) = EPrints::Subject::all_subject_labels( 
				$self->{session} ); 
		}
		else
		{			
			( $sub_tags, $sub_labels ) = EPrints::Subject::get_postable( 
				$self->{session}, 
				$self->{session}->current_user );
		}

		my $height = ( $EPrints::HTMLRender::list_height_max < $#{$sub_tags}+1 ?
		               $EPrints::HTMLRender::list_height_max : $#{$sub_tags}+1 );

		my @selected_tags = $subject_list->get_tags();

		$html = $self->{query}->scrolling_list(
			-name=>$field->{name},
			-values=>$sub_tags,
			-default=>\@selected_tags,
			-size=>$height,
			-multiple=>( $field->{multiple} ? "true" : undef ),
			-labels=>$sub_labels );
	}
	elsif( $type eq "name" )
	{
		# Get the names out
		my @names = EPrints::Name::extract( $value );

		my $boxcount = $self->{nameinfo}->{"name_boxes_$field->{name}"};

		if( defined $self->{nameinfo}->{"name_more_$field->{name}"} )
		{
			$boxcount += $EPrints::HTMLRender::add_boxes;
		}

		# Ensure at least 1...
		$boxcount = 1 if( !defined $boxcount );
		# And that there's enough to fit all the names in
		$boxcount = $#names+1 if( $boxcount < $#names+1 );
		my $i;
		# Render the boxes
		for( $i = 0; $i < $boxcount; $i++ )
		{
			my( $familyname, $firstnames );
			
			if( $i <= $#names )
			{
				( $familyname, $firstnames ) = @{$names[$i]};
			}
					
			$html .= "</tr>\n<tr><td>";
			$html .= "</td>";
		}
		
		if( $field->{multiple} )
		{
			$html .= "<td>".$self->named_submit_button( 
				"name_more_$field->{name}",
				$self->{session}->phrase( "F:more_spaces" ) );
			$html .= $self->hidden_field( "name_boxes_$field->{name}", $boxcount );
			$html .= "</td>";
		}
		
		$html .= "</tr>\n</table>\n";
	}
	elsif( $type eq "username" )
	{
		# Get the usernames out
		my @usernames = EPrints::User::extract( $value );

		my $boxcount = $self->{usernameinfo}->{"username_boxes_$field->{name}"};

		if( defined $self->{usernameinfo}->{"username_more_$field->{name}"} )
		{
			$boxcount += $EPrints::HTMLRender::add_boxes;
		}

		# Ensure at least 1...
		$boxcount = 1 if( !defined $boxcount );
		# And that there's enough to fit all the usernames in
		$boxcount = $#usernames+1 if( $boxcount < $#usernames+1 );

		# Render the boxes
		$html = "<table border=0><tr><th>";
		$html.= $self->{session}->phrase( "H:username_title" );
		$html.= "</th>";
		
		my $i;
		for( $i = 0; $i < $boxcount; $i++ )
		{
			my $username;	
			if( $i <= $#usernames )
			{
				( $username ) = $usernames[$i];
			}
					
			$html .= "</tr>\n<tr><td>";
			$html .= $self->{query}->textfield(
				-name=>"username_$i"."_$field->{name}",
				-default=>$username,
				-size=>$EPrints::HTMLRender::form_username_width,
				-maxlength=>$EPrints::HTMLRender::field_max );
			$html .= "</td>";
		}
		
		if( $field->{multiple} )
		{
			$html .= "<td>".$self->named_submit_button( 
				"username_more_$field->{name}",
				$self->{session}->phrase( "F:more_spaces" ) );
			$html .= $self->hidden_field( "username_boxes_$field->{name}", $boxcount );
			$html .= "</td>";
		}
		
		$html .= "</tr>\n</table>\n";
	}
	else
	{
		$html = "N/A";

	}
	
	return( $html );
}

#WP1: BAD
sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = $session->phrase( "month_".$month );
	}

	return $months;
}

