#####################################################################
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

#cjg =- None of the SQL values are ESCAPED - do it at one go later!

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
#  email, XXXXXXXXXXXurl    "searchvalue" (simple)
#  XXXX & eprinttype        "poss1:poss2:poss3"
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
	"eprinttype" => "Select one or more values from the list. Default is (Any).",
	"multitext"  => $texthelp,
	"name"       => $texthelp,
	"set"        => "Select one or more values from the list, and whether you ".
	                "want to search for records with any one or all of those ".
	                "values. Default is (Any).",
	"subject"    => "Select one or more values from the list, and whether you ".
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

@EPrints::SearchField::text_search_types = ( "ALL", "ANY" );

%EPrints::SearchField::text_search_type_labels =
(
	"ALL" => "Match all, in any order",
	"ANY" => "Match any"
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
	$self->{value} = $value;

	$self->process_value();

		
	if( ref( $field ) eq "ARRAY" )
	{
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
		$self->{type} = $field->[0]->{type};
	}
	else
	{
		$self->{field} = $field;
		$self->{displayname} = $field->{displayname};
		$self->{formname} = $field->{name};
		$self->{type} = $field->{type};
	}
	

	return( $self );
}

sub process_value
{
	my ( $self ) = @_;

	$self->{value} =~ m/^([A-Z][A-Z][A-Z]):([A-Z][A-Z]):(.*)$/i;
	$self->{anyall} = uc $1;
	$self->{match} = uc $2;
	$self->{string} = $3;

	# Value has changed. Previous benchmarks no longer apply.
	$self->{benchcache} = {};

	print STDERR "NEW SE ($1)($2)($3) [$self->{value}] \n";
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
			-default=>( defined $self->{string} ? $self->{string} : $tags[0] ),
			-labels=>\%labels );
	}
	elsif( $type eq "email" || $type eq "url" )
	{
		# simple text types
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{string},
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );
	}
	elsif( $type eq "multitext" || $type eq "text" || $type eq "name" )
	{
		# complex text types
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{string},
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		$html .= $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname}."_srchtype",
			-values=>\@EPrints::SearchField::text_search_types,
			-default=>$self->{anyall},
			-labels=>\%EPrints::SearchField::text_search_type_labels );
	}
	elsif( $type eq "username" )
	{
		my @defaults;
		my $anyall = "ANY";
		
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{string},
			-size=>$EPrints::HTMLRender::search_form_width,
			-maxlength=>$EPrints::HTMLRender::field_max );

		my @anyall_tags = ( "ANY", "ALL" );
		my %anyall_labels = ( "ANY" => "Any of these", "ALL" => "All of these" );

		$html .= $self->{session}->{render}->{query}->popup_menu(
			-name=>$self->{formname}."_anyall",
			-values=>\@anyall_tags,
			-default=>$self->{anyall},
			-labels=>\%anyall_labels );
	}
	elsif( $type eq "eprinttype" )
	{
		my @defaults;
		
		# Do we have any values already?
		if( defined $self->{string} && $self->{string} ne "" )
		{
			@defaults = split /\s/, $self->{string};
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
	elsif( $type eq "set" || $type eq "subject" )
	{
		my @defaults;
		my $anyall = "ANY";
		
		# Do we have any values already?
		if( defined $self->{string} && $self->{string} ne "" )
		{
			@defaults = split /\s/, $self->{string};
			$anyall = pop @defaults;
		}
		else
		{
			@defaults = ();
		}
		
		# Make a list of possible values
		my( $values, $labels );
		
		if( $type eq "subject" )
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
			-default=>$self->{anyall},
			-labels=>\%anyall_labels );
	}
	elsif( $type eq "int" )
	{
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{string},
			-size=>9,
			-maxlength=>100 );
	}
	elsif( $type eq "year" )
	{
		$html = $self->{session}->{render}->{query}->textfield(
			-name=>$self->{formname},
			-default=>$self->{string},
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
		$self->{value} = "ALL:EQ:$val" if( $val ne "EITHER" );;
	}
	elsif( $type eq "email" || $type eq "url" )
	{
		# simple text types
		my $val = $self->{session}->{render}->param( $self->{formname} );
		if( defined $val && $val ne "" )
		{
			$self->{value} = "ANY:IN:$val";
		}
	}
	elsif( $type eq "multitext" || $type eq "text" || $type eq "name" )
	{
		# complex text types
		my $search_terms = $self->{session}->{render}->param( $self->{formname} );
		my $search_type = $self->{session}->{render}->param( 
			$self->{formname}."_srchtype" );
		my $exact = "IN";
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$search_type = "ALL" unless defined( $search_type );		
		
		if( defined $search_terms && $search_terms ne "" ) 
		{
			$self->{value} = "$search_type:$exact:$search_terms";
		}
	}		
	elsif( $type eq "username" )
	{
		# usernames
		my $anyall = $self->{session}->{render}->param( 
			$self->{formname}."_anyall" );
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$anyall = "ALL" unless defined( $anyall );		
		my $exact = "IN";
	
		my @vals = split /\s+/ , $self->{session}->{render}->param( $self->{formname} );
		if( scalar @vals > 0)
		{
			$self->{value} = "$anyall:$exact:".join( " " , @vals );
		}
	}		
	elsif( $type eq "eprinttype" )
	{
		my @vals = $self->{session}->{render}->param( $self->{formname} );
		
		if( scalar @vals > 0 )
		{
			# We have some values. Join them together.
			my $val = join ' ', @vals;

			# But if one of them was the "any" option, we don't want a value.
			foreach (@vals)
			{
				undef $val if( $_ eq "NONE" );
			}

			$self->{value} = "ANY:EQ:$val";
		}
	}
	elsif( $type eq "set" || $type eq "subject" )
	{
		my @vals = $self->{session}->{render}->param( $self->{formname} );
		my $val;
		
		if( scalar @vals > 0 )
		{
			# We have some values. Join them together.
			$val = join ' ', @vals;

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
				
			$val = (defined $anyall? "$anyall" : "ANY" ).":EQ:$val";

			$self->{value} = $val;
		}

	}
	elsif( $type eq "year" )
	{
		my $val = $self->{session}->{render}->param( $self->{formname} );
		
		if( defined $val && $val ne "" )
		{
			if( $val =~ /^(\d\d\d\d)?\-?(\d\d\d\d)?/ )
			{
				$self->{value} = "ANY:EQ:$val";
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

	$self->process_value();

	return( $problem );
}
	

##########################################################
# 
# cjg commentme (all below)

sub get_conditions 
{
	my ( $self , $benchmarking ) = @_;

print STDERR "get_condititions: ($self->{field}->{type},$self->{field}->{name})\n";

	if ( !defined $self->{value} || $self->{value} eq "" )
	{
		return undef;
	}

	if ( $self->{field}->{type} eq "set" || $self->{field}->{type} eq "subject" || 
		$self->{field}->{type} eq "eprinttype" || $self->{field}->{type} eq "boolean" ||
		$self->{field}->{type} eq "username" )
	{
		my @fields = ();
		my $text = $self->{string};
		while( $text=~s/"([^"]+)"// ) { push @fields, $1; }
		while( $text=~s/([^\s]+)// ) { push @fields, $1; }
		my @where;
		foreach( @fields )
		{
			my $s = "__FIELDNAME__ = '$_'";
			push @where , $s;
		}	
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	if ( $self->{field}->{type} eq "name" )
	{
		my @where = ();
		my @names = ();
		my $text = $self->{string};
		while( $text=~s/"([^"]+)"// ) { push @names, $1; }
		while( $text=~s/([^\s]+)// ) { push @names, $1; }
		foreach( @names )
		{
			m/^([^,]+)(,(.*))?$/;
			my ( $family , $given ) = ( $1 , $3 );
			if ( $self->{match} eq "IN" )
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
				$s = "($s AND __FIELDNAME___given LIKE '$given')";
			}
			push @where , $s;
		}	
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	# year, int
	#
	# N
	# N-
	# -N
	# N-N

	if ( $self->{field}->{type} eq "year"
	  || $self->{field}->{type} eq "int" )
	{
		my @where = ();
		foreach( split /\s+/ , $self->{string} )
		{
			my $sql;
			if( m/^(\d+)?\-(\d+)?$/ )
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
			elsif( m/^\d+$/ )
			{
				$sql = "__FIELDNAME__ = \"$_\"";
			}
			if( !defined $sql )
			{
				my $error = "Bad ".$self->{field}->{type};
				$error.=" search parameter: \"$_\"";
				return( undef,undef,undef,$error);
			}
			push @where, $sql;
		}
		return( $self->_get_conditions_aux( \@where , 0) , [] );
	}

	# date
	#
	# YYYY-MM-DD 
	# YYYY-MM-DD-
	# -YYYY-MM-DD
	# YYYY-MM-DD-YYYY-MM-DD

	if( $self->{field}->{type} eq "date" )
	{
		my @where = ();
		foreach( split /\s+/ , $self->{string} )
		{
			my $sql;
			if( m/^(\d\d\d\d\-\d\d\-\d\d)?\-(\d\d\d\d\-\d\d\-\d\d)?$/ )
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
			elsif( m/^(\d\d\d\d\-\d\d\-\d\d)$/ )
			{
				$sql = "__FIELDNAME__ = \"$1\"";
			}
			if( !defined $sql )
			{
				my $error = "Bad ".$self->{field}->{type};
				$error.=" search parameter: \"$_\"";
				return( undef,undef,undef,$error);
			}
			push @where, $sql;
		}
		return( $self->_get_conditions_aux( \@where , 0) , []);
	}

	# text, multitext, url, email:
	#
	#  word word "a phrase" word
	#

	if ( $self->{field}->{type} eq "text" ||  $self->{field}->{type} eq "multitext" ||
		$self->{field}->{type} eq "url" ||  $self->{field}->{type} eq "email")
	{
		my @where = ();
		my @phrases = ();
		my $text = $self->{string};
		if ( $self->{anyall} eq "PHR" ) 
		{
			# PHRASES HAVE SPECIAL HANDLING!

			# If we want an exact match just return records which exactly
			# match this phrase.

			if( $self->{match} eq "EQ" )
			{
				return ( $self->_get_conditions_aux( [ "__FIELDNAME__ = \"$text\"" ], 0 ), [] );
			}
			my( $good , $bad ) = 
				EPrintSite::SiteRoutines::extract_words( $text );

			# If there are no useful words in the phrase, abort!
			if( scalar @{$good} == 0) {
				return(undef,undef,undef,"No indexable words in phrase \"$text\".");
			}
			foreach( @{$good} )
			{
				if( $self->{match} eq "IN" )
				{
					$_ = "$self->{field}->{name}:$_";
				}
				push @where, "__FIELDNAME__ = '$_'";
			}
			return ( $self->_get_conditions_aux( \@where ,  1 ) , [] );

		}
		my $hasphrase = 0;
		while ($text =~ s/"([^"]+)"//g)
		{
			if( !$benchmarking )
			{
				my $sfield = new EPrints::SearchField( 
					$self->{session},
					$self->{table},
					$self->{field},
					"PHR:IN:$1" );
				my ($buffer,$bad,$error) = $sfield->do( undef , undef );
				if( defined $error )
				{
					return( undef, undef, undef, $error );
				}
				push @where,"!$buffer"; 
			}
			else
			{
				# Just benchmarking - we'll return a search condition of "1=0"
				# Which is always false so will be optimisted out and this will
				# evaluate as 0 meaning it will go first. Which makes sense as
				# this cannot (is not) optimised.	
				push @where, "1=0";
			}
			$hasphrase=1;
		}
		my( $good , $bad ) = 
			EPrintSite::SiteRoutines::extract_words( $text );

		if( scalar @{$good} == 0 && !$hasphrase )
		{
			return(undef,undef,undef,"Search field contains no indexable words: \"$text\".");
		}

		foreach( @{$good} )
		{
			if( $self->{match} eq "IN" )
			{
				$_ = "$self->{field}->{name}:$_";
			}
			push @where, "__FIELDNAME__ = '$_'";
		}
		return ( $self->_get_conditions_aux( 
				\@where ,  
				$self->{match} eq "IN" ) , $bad );
	}

}

sub _get_conditions_aux
{
	my ( $self , $wheres , $freetext ) = @_;
print STDERR "_GCA($self->{field}->{name})\n";
	my $searchtable = $self->{table};
	if ($self->{field}->{multiple}) 
	{	
		$searchtable.= $EPrints::Database::seperator.$self->{field}->{name};
	}	
	if( $freetext )
	{
		$searchtable = EPrints::Database::index_name( $self->{table} );
	}

	my $fieldname = "M.".($freetext ? "fieldword" : $self->{field}->{name} );

	my @nwheres; # normal
	my @pwheres; # pre-done
	foreach( @{$wheres} )
	{
		if( $_ =~ m/^!/ )
		{
			print STDERR ">>> $_\n";
			push @pwheres, $_;
		}
		else
		{
			s/__FIELDNAME__/$fieldname/g;
			push @nwheres, $_;
		}
	}

	if ( $self->{anyall} eq "ANY" ) 
	{
		if( scalar @nwheres == 0 )
		{
			@nwheres = ();
		}
		else
		{
			@nwheres = ( join( " OR " , @nwheres ) );
		}
	}
	push @nwheres , @pwheres;

	return "$searchtable:$self->{field}->{name}" , \@nwheres;

}

# cjg comments

sub benchmark
{
	my ( $self , $tablefield , $where ) = @_;

	my( $table , $field ) = split /:/ , $tablefield;

        my @fields = EPrints::MetaInfo::get_fields( $self->{table} );
        my $keyfield = $fields[0];

	if ( !defined $self->{benchcache}->{"$table:$where"} )
	{
		$self->{benchcache}->{"$table:$where"} = 
			$self->{session}->{database}->benchmark( 
				$keyfield,
				{ "M"=>$table }, 
				$where );
		EPrints::Log::debug("cache: $table:$where");
	}
	else
	{
		EPrints::Log::debug("used cache: $table:$where");
	}
	return $self->{benchcache}->{"$table:$where"};

}

# benchmarking means that we only need to get approx 
# results from this...

sub _get_tables_searches
{
	my ( $self , $benchmarking) = @_;

	my %searches = ();
	my @tables = ();
	my @badwords = ();
	if( defined $self->{multifields} )
	{
		foreach( @{$self->{multifields}} ) 
		{
			my $sfield = new EPrints::SearchField( 
				$self->{session},
				$self->{table},
				$_,
				$self->{value} );
			my ($table,$where,$bad,$error) = 
				$sfield->get_conditions( $benchmarking );
			if( defined $error )
			{
				return( undef, undef, undef, $error );
			}
print STDERR "_GTS($table)\n";
			if( !defined $searches{$table} )
			{
				push @tables,$table;
				$searches{$table}=[];
			}
			push @{$searches{$table}},@{$where};
print STDERR "WHERE\n";
print STDERR join(" | ",@{$where})."\n";
			if( defined $bad ) { push @badwords, @{$bad}; }
		}
	}
	else 
	{
		my ($table,$where,$bad,$error) = $self->get_conditions( $benchmarking );
		if( defined $error )
		{
			return( undef, undef, undef, $error );
		}
		push @tables, $table;
		$searches{$table} = $where;
		if( defined $bad ) { push @badwords, @{$bad}; }
	}
	return (\@tables, \%searches, \@badwords);
}

sub do
{
	my ( $self , $searchbuffer , $satisfy_all) = @_;
	
        my @fields = EPrints::MetaInfo::get_fields( $self->{table} );
        my $keyfield = $fields[0];

	my ($sfields, $searches, $badwords, $error) = $self->_get_tables_searches();
	if( defined $error ) 
	{
		return ( undef , undef , $error );
	}
	my $n = scalar @{$searches->{$sfields->[0]}};
	
	#my @forder = sort { $self->benchmark($table,$a) <=> $self->benchmark($table,$b) } @{$where};
EPrints::Log::debug("n: [$n] ");
EPrints::Log::debug("sfields: [".join("][",@{$sfields})."] ");

	my $buffer = undef;
	if( !$satisfy_all && $self->{anyall} eq "ANY" )
	{
		# don't create a new buffer, just dump more 
		# values into the current one.
		$buffer = $searchbuffer;
	}
	my $i;
	
	# I use "ne ANY" here as a fast way to mean "eq PHR" or "eq AND"
	# (phrases subsearches are always AND'd)

print STDERR "<SEARCH : $self->{value}   IN   $self->{field}->{name}\n";
	for( $i=0 ; $i<$n ; ++$i )
	{
		my $nextbuffer = undef;
print STDERR "<SEARCH ITEM: $i\n";
		foreach( @{$sfields} )
		{
print STDERR "<TABLE : $_\n";
			my $tablename = $_;
			# Tables have a colon and fieldname after them
			# to make sure references to different fields are
			# still kept seperate. But we don't want to pass
			# this to the SQL.
			$tablename =~ s/:.*//;

			my $tlist = { "M"=>$tablename };
			my $orbuf = undef;
			if( $self->{anyall} eq "ANY" && defined $buffer )
			{
				$orbuf = $buffer;
			}
			if( defined $nextbuffer )
			{
				$orbuf = $nextbuffer;
			}
			if( $satisfy_all && defined $searchbuffer )
			{
				$tlist->{T} = $searchbuffer;
			}
			if( $self->{anyall} ne "ANY" && defined $buffer )
			{
				$tlist->{T} = $buffer;
			}

			my $where = $searches->{$_}->[$i];

			# Starting with a pling! means that this is a pre
			# done search and we should just link against the
			# results buffer table.
			if( $where =~ s/^!// )
			{
				$tlist->{M} = $where;
				$where = undef;
			}

			$nextbuffer = $self->{session}->{database}->buffer( 
				$keyfield,
				$tlist, 
				$where,
				$orbuf );
print STDERR "</TABLE : $_\n";
		}
		$buffer = $nextbuffer;
print STDERR "</SEARCH ITEM: $i\n";
	}
	if( $self->{anyall} eq "PHR" )
	{
		print STDERR "==================================\nRIGHT NOW $self->{string}\n==============\n";
		my( $tablefield , $wheres ) = $self->_get_conditions_aux( 
						["__FIELDNAME__ LIKE \"%$self->{string}%\""] , 
						0 );
		my $table = $tablefield;
		$table=~s/:.*//;
print STDERR "($table)(".join(")(",@{$wheres}).")\n";
print STDERR "HMMMM: ".$self->{table}."\n";
print STDERR "HMMMM: ".$self->{field}->{name}."\n";
		my $tlist = { "M"=>$table };
		$buffer = $self->{session}->{database}->buffer( 
			$keyfield,
			$tlist, 
			${$wheres}[0],
			undef );
	}
print STDERR "</SEARCH : $self->{value}   IN   $self->{field}->{name}\n";

	if( $self->{anyall} ne "ANY" && !$satisfy_all )
	{
		$buffer = $self->{session}->{database}->buffer( 
			$keyfield,
			{ "T"=>$buffer },
			undef,
			$searchbuffer );
	}

EPrints::Log::debug("retbuffer: [$buffer]");
	return ( $buffer, $badwords );

}

sub approx_rows 
{
	my ( $self ) = @_;

EPrints::Log::debug("APPROX ROWS START: $self->{displayname}");

	my ($tables, $searches, $badwords, $error) = $self->_get_tables_searches( 1 );
	if( defined $error )
	{
		return 0;
	}
	my $n = scalar @{$searches->{$tables->[0]}};

	my $result = undef;
	my $i;
	for( $i=0 ; $i<$n ; ++$i )
	{
		my $i_result = undef;
		foreach( @{$tables} )
		{
			my $rows = $self->benchmark( $_ , $searches->{$_}->[$i] ); 
			if( !defined $i_result )
			{
				$i_result = $rows;
			}
			else
			{
				$i_result+= $rows;
			}
		}
		if( !defined $result )
		{
			$result = $i_result;
		}
		elsif( $self->{anyall} eq "ANY" )
		{
			$result+= $i_result;
		}
		else
		{
			if( $i_result < $result )
			{
				$result = $i_result;
			}
		}
		
	}

EPrints::Log::debug("APPROX ROWS END: $self->{displayname}: $result");
	return $result;
}


1;
