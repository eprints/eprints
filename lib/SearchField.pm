######################################################################
#
#  Search Field
#
#   Represents a single field in a search.
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

package EPrints::SearchField;

use EPrints::Session;
use EPrints::Database;
use EPrints::HTMLRender;
use EPrints::Subject;
use EPrints::Log;

use Text::ParseWords;
use strict;

######################################################################
#
#  Format of field values. In all cases, undef or "" means don't bother
#   doing a search for it.
#
#  boolean:                 "TRUE", "FALSE" (or undef for either)
#  date:                    "YYYY-MM-DD-" = any date from specified onwards
#                           "-YYYY-MM-DD" = any date up until and including
#                           "YYYY-MM-DD-YYYY-MM-DD" = between those dates (incl)
#                           "YYYY-MM-DD" = just on that day
#  email, multiurl & url    "searchvalue" (simple)
#  enum & eprinttype        "poss1:poss2:poss3"
#  multitext, text & name   "[all][any][phr]:terms"
#  username, set & subject  "val1:val2:val3:[ANY|ALL]"
#  year                     "YYYY-" = any year from YYYY onwards
#                           "-YYYY" = any year up to YYYY
#                           "YYYY-ZZZZ" = any year from YYYY to ZZZZ (incl.)
#                           "YYYY" - just the year YYYY
#
#  No support yet for searching pagerange or int values.
#
######################################################################

my $texthelp = "Enter a term or terms to search for.";

%EPrints::SearchField::search_help =
(
	"boolean"    => "Select a value.",
	"email"      => "Enter some text to search for",
	"enum"       => "Select one or more values from the list. Default is (Any).",
	"eprinttype" => "Select one or more values from the list. Default is (Any).",
	"multitext"  => $texthelp,
	"multiurl"   => "Enter some text to search for",
	"name"       => $texthelp,
	"set"        => "Select one or more values from the list, and whether you ".
	                "want to search for records with any one or all of those ".
	                "values. Default is (Any).",
	"subjects"   => "Select one or more values from the list, and whether you ".
	                "want to search for records with any one or all of those ".
	                "values. Default is (Any).",
	"username"   => "Enter one or more usernames (space seperated) and whether you ".
	                "want to search for records with any one or all of those ".
	                "values. Default is (Any).",
	"text"       => $texthelp,
	"url"        => "Enter some text to search for",
	"year"       => "Enter a single year (e.g. 1999), or a range of years, ".
	                "e.g. `1990-2000', `1990-' or -2000'."
);

@EPrints::SearchField::text_search_types = ( "all", "any", "phr" );

%EPrints::SearchField::text_search_type_labels =
(
	"all" => "Match all, in any order",
	"any" => "Match any",
	"phr" => "Match as a phrase"
);


######################################################################
#
# $field = new( $session, $table, $field, $value )
#
#  Create a new search field for the metadata field $field. $value
#  is a default value, if there's one already. You can pass in a
#  reference to an array for $field, in which case the fields will
#  all be searched using the one search value (OR'd). This only works
#  (and is useful) for fields of types listed together at the top of
#  the file (e.g. "text" and "multitext", or "email" and "url", but not
#  "year" and "boolean").
#  We need to know the name of the table to build the name of aux.
#  table.
#
######################################################################

sub new
{
	my( $class, $session, $table, $field, $value ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{table} = $table;

	if( ref( $field ) eq "ARRAY" )
	{
		print STDERR "!!!!!!!!!!!!!!!!!!!!!!!!!\nDEBUG ME - need to call self multiple times?\n!!!!!!!!!!!!!!!!!!!!!\n";
		# Search >1 field
		$self->{multifields} = $field;

		my( @fieldnames, @displaynames );
		foreach (@$field)
		{
			push @fieldnames, $_->{name};
			push @displaynames, $_->{displayname};

		}
		$self->{displayname} = join '/', @displaynames;
		$self->{formname} = join '_', @fieldnames;
		$self->{type} = $self->{multifields}->[0]->{type};
	}
	else
	{
		$self->{field} = $field;
		$self->{displayname} = $field->{displayname};
		$self->{formname} = $field->{name};
		$self->{type} = $field->{type};
	}
	
	$self->{value} = $value;

	return( $self );
}


######################################################################
#
# $sql = get_sql()
#
#  Get the condition(s), in SQL form, that will retrieve relevant
#  results for this search term. undef is returned if the term does
#  not affect the results of the search.
#
######################################################################

sub get_sql
{
	my( $self ) = @_;
	
#EPrints::Log::debug( "SearchField", "making SQL for $self->{formname} of type $self->{type}" );
#EPrints::Log::debug( "SearchField", "Value is $self->{value}" );

	unless( defined $self->{value} && $self->{value} ne "" )
	{
		return ( undef , undef );
	}

	# Get the SQL for a single term

	my $type = $self->{type};
	my $value = $self->{value};
	
	# boolean
	#
	# TRUE 
	# FALSE

	if( $type eq "boolean" )
	{
		return $self->_get_sql_aux( 
			"ANY",
			"__FIELDNAME__ = '$value'" );
	}

	# date
	#
	# YYYY-MM-DD 
	# YYYY-MM-DD-
	# -YYYY-MM-DD
	# YYYY-MM-DD-YYYY-MM-DD

	if( $type eq "date" )
	{
		my $sql;
		if( $value =~ /^(\d\d\d\d\-\d\d\-\d\d)?\-(\d\d\d\d\-\d\d\-\d\d)?$/ )
		{
			# Range of dates
			if( defined $1 && $1 ne "" )
			{
				if( defined $2 && $2 ne "" )
				{
					# YYYY-MM-DD-YYYY-MM-DD
					$sql = "__FIELDNAME__ BETWEEN \"$1\" AND \"$2\"";
				}
				else
				{
					# YYYY-MM-DD-
					$sql = "__FIELDNAME__ >= \"$1\"";
				}
			}
			elsif( defined $2 && $2 ne "" )
			{
				# -YYYY-MM-DD
				$sql = "__FIELDNAME__ <= \"$2\"";
			}
			# Otherwise, must be invalid
		}
		else
		{
			$sql = "__FIELDNAME__ = \"$value\"";
		}
		if ( defined $sql )
		{
			# An empty value is passed to force the
			# routine to generate one clause.
			return $self->_get_sql_aux( "ANY" , $sql );
		}	
		return ( "BAD_DATE_SEARCH" , undef );
	}

	# email, url, multiurl
	# text, multitext
	#
	# ANY|ALL|PHR:IN|EQ:foo bar...

	if( $type eq "email" || $type eq "multiurl" || $type eq "url" ||
		$type eq "text" || $type eq "multitext"	)
	{
		unless ($value =~ m/^(ANY|ALL|PHR):(IN|EQ):(.*)$/)
		{
			return ( "BAD_"."\U$type"."_SEARCH" , undef );
		}
		my $mode = $1;
		my $match = $2;
		my @vals;
		if ( $mode eq "PHR" ) 
		{
			$vals[0] = $3;
			$mode = "ANY";
		}
		else
		{
			@vals = split /\s+/ , $3 ;
		}

		my @sql;
		foreach( @vals )
		{
			if ( $match eq "IN" ) 
			{
				push @sql,"__FIELDNAME__ LIKE '\%$_\%'";
			}
			else
			{
				push @sql,"__FIELDNAME__ = '$_'";
			}
		}
		# mode is ALL or ANY
		return $self->_get_sql_aux( $mode , @sql );
	}

	# set, subjects, username
	# enum, eprinttype
	#
	# ANY|ALL:foo:bar:...
	
	if( $type eq "set" || $type eq "subjects" || $type eq "username" ||
		$type eq "enum" || $type eq "eprinttype" ) 
	{
		my @sql;
		my @vals = split /:/, $value;
		my $mode = shift @vals;
		foreach( @vals )
		{
			push @sql , "__FIELDNAME__ = '$_'";
		}

		return $self->_get_sql_aux( $mode , @sql );

	}

	# year, int
	#
	# N
	# N-
	# -N
	# N-N

	if( $type eq "year" || $type eq "int" )
	{
		my $sql;
		if( $value =~ /^(\d+)?\-(\d+)?$/ )
		{
			# Range of numbers
			if( defined $1 && $1 ne "" )
			{
				if( defined $2 && $2 ne "" )
				{
					# N-N
					$sql = "__FIELDNAME__ BETWEEN $1 AND $2";
				}
				else
				{
					# N-
					$sql = "__FIELDNAME__ >= $1";
				}
			}
			elsif( defined $2 && $2 ne "" )
			{
				# -N
				$sql = "__FIELDNAME__ <= $2";
			}

			# Otherwise, must be invalid
		}
		else
		{
			$sql = "__FIELDNAME__ = \"$value\"";
		}
		if ( defined $sql )
		{
			# An empty value is passed to force the
			# routine to generate one clause.
			return $self->_get_sql_aux( "ANY" , $sql );
		}	
		return ( "BAD_"."\U$type"."_SEARCH" , undef );
	}

	# name
	#
	# ANY|ALL|EQ|IN:smith:jones,bob:...

	if( $type eq "name" )
	{
		my @vals = split /:/ , $value ;
		my $mode = shift @vals;
		my $match = shift @vals;
		my @sql;
		foreach( @vals )
		{
			m/^([^,])+(,(.*))?$/;
			my ( $family , $given ) = ( $1 , $3 );
			if ( $match eq "IN" )
			{
				$family .= "\%";
				if ( defined $given )
				{
					$given .= "\%";
				}
			}
			my $s = "__FIELDNAME___family LIKE '$family'";
			if ( defined $given )
			{
				$s.= "__FIELDNAME___given LIKE '$given'";
			}
			push @sql , $s;
		}	
		return $self->_get_sql_aux( $mode , @sql );
		
	}

#EPrints::Log::debug( "SearchField", "SQL = $all_sql" );

	return( "UNKNOWN_TYPE" , undef );
}

sub _get_sql_aux
{
	my ( $self , $mode , @sqlbits ) = @_;

	my $sql = "";
	my %auxtables = ();

	my $count = 0;

	# Put the values together into a WHERE clause. 
	my $auxtable;
	if ($self->{field}->{multiple}) 
	{	
		$auxtable = $self->{table}."aux".$self->{field}->{name};
	}	
	my $bit;
	foreach $bit (@sqlbits)
	{
		my $auxalias;
		if ( $mode eq "ANY" ) 
		{
			$sql .= " OR " if ( $count > 0);
			$auxalias = "__aux__";
		} 
		else
		{
			$sql .= " AND " if ( $count > 0);
			$auxalias = "__aux".$count."__";
		}
		if ($self->{field}->{multiple}) 
		{
			$auxtables{$auxalias} = $auxtable;
		}
		else
		{
			$auxalias = $self->{table};
		}
		$bit =~ s/__FIELDNAME__/$auxalias.$self->{field}->{name}/g;
		$sql .= $bit;

		$count++;
	}
	return( $sql , \%auxtables );
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
	my( $self ) = @_;
	
#EPrints::Log::debug( "SearchField", "rendering field $self->{formname} of type $self->{type}" );

	my $html;
	my $type = $self->{type};
	
	if( $type eq "boolean" )
	{
		# Boolean: Popup menu
		my %labels = ( "EITHER" => "No Preference",
		               "TRUE"   => "Yes",
		               "FALSE"  => "No" );

		my @tags = ( "EITHER", "TRUE", "FALSE" );
		
		my $default = ( defined $self->{value} ? "EITHER" : $self->{value} );

		$html = $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname},
			-values=>\@tags,
			-default=>( defined $self->{value} ? $self->{value} : $tags[0] ),
			-labels=>\%labels );
	}
	elsif( $type eq "email" || $type eq "multiurl" || $type eq "url" )
	{
		# simple text types
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{value},
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );
	}
	elsif( $type eq "multitext" || $type eq "text" || $type eq "name" )
	{
		# complex text types
		my( $search_type, $search_phrases ) = _get_search_type( $self->{value} );
		
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$search_phrases,
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		$html .= $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname}."_srchtype",
			-values=>\@EPrints::SearchField::text_search_types,
			-default=>$search_type,
			-labels=>\%EPrints::SearchField::text_search_type_labels );
	}
	elsif( $type eq "username" )
	{
		my @defaults;
		my $anyall = "ANY";
		
		# Do we have any values already?
		if( defined $self->{value} && $self->{value} ne "" )
		{
			@defaults = split /:/, $self->{value};
			$anyall = pop @defaults;
		}
		else
		{
			@defaults = ();
		}
		
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>join( " " , @defaults ),
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		my @anyall_tags = ( "ANY", "ALL" );
		my %anyall_labels = ( "ANY" => "Any of these", "ALL" => "All of these" );

		$html .= $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname}."_anyall",
			-values=>\@anyall_tags,
			-default=>$anyall,
			-labels=>\%anyall_labels );
	}
	elsif( $type eq "enum" || $type eq "eprinttype" )
	{
		my @defaults;
		
		# Do we have any values already?
		if( defined $self->{value} && $self->{value} ne "" )
		{
			@defaults = split /:/, $self->{value};
		}
		else
		{
			@defaults = ();
		}
		
		# Make a list of possible values
		my( $values, $labels );
		
		if( $type eq "eprinttype" )
		{
			my @eprint_types = EPrints::MetaInfo::get_eprint_types();
			( $values, $labels ) = _add_any_option(
				\@eprint_types,
				EPrints::MetaInfo::get_eprint_type_names() );
		}
		else
		{
			( $values, $labels ) = _add_any_option(
				$self->{field}->{tags},
				$self->{field}->{labels} );
		}		

		$html = $self->{session}->{render}->{query}->scrolling_list(
			-name=>$self->{formname},
			-values=>$values,
			-default=>\@defaults,
			-size=>( scalar @$values > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$values ),
			-multiple=>"true",
			-labels=>$labels );
	}
	elsif( $type eq "set" || $type eq "subjects" )
	{
		my @defaults;
		my $anyall = "ANY";
		
		# Do we have any values already?
		if( defined $self->{value} && $self->{value} ne "" )
		{
			@defaults = split /:/, $self->{value};
			$anyall = pop @defaults;
		}
		else
		{
			@defaults = ();
		}
		
		# Make a list of possible values
		my( $values, $labels );
		
		if( $type eq "subjects" )
		{
			# WARNING: passes in {} as a dummy user. May need to change this
			# if the "postability" algorithm checks user info.
			( $values, $labels ) = _add_any_option(
				EPrints::Subject::get_postable( $self->{session}, {} ) );
		}
		else
		{
			( $values, $labels ) = _add_any_option(
				$self->{field}->{tags},
				$self->{field}->{labels} );
		}
		
		$html = $self->{session}->{render}->{query}->scrolling_list(
			-name=>$self->{formname},
			-values=>$values,
			-default=>\@defaults,
			-size=>( scalar @$values > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$values ),
			-multiple=>"true",
			-labels=>$labels );

		$html .= "&nbsp;";
		
		my @anyall_tags = ( "ANY", "ALL" );
		my %anyall_labels = ( "ANY" => "Any of these", "ALL" => "All of these" );

		$html .= $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname}."_anyall",
			-values=>\@anyall_tags,
			-default=>$anyall,
			-labels=>\%anyall_labels );
	}
	elsif( $type eq "year" )
	{
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{value},
			-size=>9,
			-maxlength=>9 );
	}
	else
	{
		EPrints::Log::log_entry(
			"SearchField",
			"Don't know how to render search field for type $type" );
	}

	return( $html );
}


######################################################################
#
# ( $tags, $labels ) = _add_any_option( $old_tags, $old_labels )
#
#  Given a list of tags ($old_tags) and labels ($old_labels) for a
#  scrolling list, adds the "NONE" tag and corresponding "(Any)" label.
#
######################################################################

sub _add_any_option
{
	my( $old_tags, $old_labels ) = @_;

#EPrints::Log::debug( "SearchField", "_add_any_option: $old_tags, $old_labels" );
	
	my @tags = ( "NONE" );
	my %labels = ( "NONE" => "(Any)" );
	
	push @tags, @$old_tags;
	
	foreach (keys %{$old_labels})
	{
		$labels{$_} = $old_labels->{$_};
	}

	return( \@tags, \%labels );
}


######################################################################
#
# $problem = from_form()
#
#  Update the value of the field from the form. Returns any problem
#  that might have happened, or undef if everything was OK.
#
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $problem;
	my $type = $self->{type};

	# Remove any default we have
	delete $self->{value};
	
	if( $type eq "boolean" )
	{
		my $val = $self->{session}->{render}->param( $self->{formname} );
		$self->{value} = $val if( $val ne "EITHER" );;
	}
	elsif( $type eq "email" || $type eq "multiurl" || $type eq "url" )
	{
		# simple text types
		my $val = $self->{session}->{render}->param( $self->{formname} );
		$self->{value} = $val if( defined $val && $val ne "" );
	}
	elsif( $type eq "multitext" || $type eq "text" || $type eq "name" )
	{
		# complex text types
		my $search_terms = $self->{session}->{render}->param( $self->{formname} );
		my $search_type = $self->{session}->{render}->param( 
			$self->{formname}."_srchtype" );
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$search_type = "all" unless defined( $search_type );		
		
		$self->{value} = "$search_type:$search_terms"
			if( defined $search_terms && $search_terms ne "" );
	}		
	elsif( $type eq "username" )
	{
		# usernames
		my $anyall = $self->{session}->{render}->param( 
			$self->{formname}."_anyall" );
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$anyall = "ALL" unless defined( $anyall );		
	
		my @vals = split /\s+/ , $self->{session}->{render}->param( $self->{formname} );
		$self->{value} = join( ":" , @vals ) . ":$anyall"
			if( scalar @vals > 0);
	}		
	elsif( $type eq "enum" || $type eq "eprinttype" )
	{
		my @vals = $self->{session}->{render}->param( $self->{formname} );
		
		if( scalar @vals > 0 )
		{
			# We have some values. Join them together.
			my $val = join ':', @vals;

			# But if one of them was the "any" option, we don't want a value.
			foreach (@vals)
			{
				undef $val if( $_ eq "NONE" );
			}

			$self->{value} = $val;
		}
	}
	elsif( $type eq "set" || $type eq "subjects" )
	{
		my @vals = $self->{session}->{render}->param( $self->{formname} );
		my $val;
		
		if( scalar @vals > 0 )
		{
			# We have some values. Join them together.
			$val = join ':', @vals;

			#EPrints::Log::debug( "SearchField", "Joined values: $val" );

			# But if one of them was the "any" option, we don't want a value.
			foreach (@vals)
			{
				undef $val if( $_ eq "NONE" );
			}

			#EPrints::Log::debug( "SearchField", "Joined values post NONE check: $val" );
		}

		if( defined $val )
		{
			# ANY or ALL?
			my $anyall = $self->{session}->{render}->param(
				$self->{formname}."_anyall" );
			
			$val .= (defined $anyall? ":$anyall" : ":ANY" );
		}

		$self->{value} = $val;
	}
	elsif( $type eq "year" )
	{
		my $val = $self->{session}->{render}->param( $self->{formname} );
		
		if( defined $val && $val ne "" )
		{
			if( $val =~ /^(\d\d\d\d)?\-?(\d\d\d\d)?/ )
			{
				$self->{value} = $val;
			}
			else
			{
				$problem = "A year field must be specified as a single year, e.g. ".
					"`2000', or a range of years, e.g. `1990-2000', `1990-' or ".
					"`-2000'.";
			}
		}
	}

#EPrints::Log::debug( "SearchField", "Value is <".(defined $self->{value} ? $self->{value} : "undef")."> for field $self->{formname}" );
#EPrints::Log::debug( "SearchField", "Returning <".(defined $problem ? $problem : "undef")."> for field $self->{formname}" );

	return( $problem );
}
	

######################################################################
#
# ( $search_type, $search_terms) =  _get_search_type( $value )
#
#  Extract the type and terms of a text search from the internal string
#  representation of the search field.
#
######################################################################

sub _get_search_type
{
	my( $value ) = @_;
	
	my( $search_type, $search_terms );

	if( !defined $value || $value eq "" )
	{
		# Default is "match all", and no terms entered
		$search_type = "all";
		$search_terms = "";
	}
	elsif( $value =~ /(\w\w\w):(.*)/ )
	{
		# Have the terms + the type in the string
		$search_type = $1;
		$search_terms = $2;
		
		# Ensure that we have a valid search type
		$search_type = "all"
			unless( defined(
				$EPrints::SearchField::text_search_type_labels{$search_type} ) );
	}
	else
	{
		# No type, just the terms
		$search_type = "all";
		$search_terms = $value;
	}
	
	return( $search_type, $search_terms );
}

1;
