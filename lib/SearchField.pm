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
use EPrints::Subject;

use strict;

# Nb. match=EX searches CANNOT be used in the HTML form (currently)
# EX is "Exact", like EQuals but allows blanks.
# EX search on subject only searches for that subject, not things
# below it.

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
#  XXXX & datatype        "poss1:poss2:poss3"
#  longtext, text & name   "[all][any][phr]:terms"
#  set & subject  "val1:val2:val3:[ANY|ALL]"
#  year                     "YYYY-" = any year from YYYY onwards
#                           "-YYYY" = any year up to YYYY
#                           "YYYY-ZZZZ" = any year from YYYY to ZZZZ (incl.)
#                           "YYYY" - just the year YYYY
#
#  No support yet for searching pagerange or int values.
#
######################################################################




######################################################################
#
# $field = new( $session, $dataset, $field, $value )
#
#  Create a new search field for the metadata field $field. $value
#  is a default value, if there's one already. You can pass in a
#  reference to an array for $field, in which case the fields will
#  all be searched using the one search value (OR'd). This only works
#  (and is useful) for fields of types listed together at the top of
#  the file (e.g. "text" and "longtext", or "email" and "url", but not
#  "year" and "boolean").
#  We need to know the name of the table to build the name of aux.
#  table.
#
######################################################################

## WP1: BAD
#cjg MAKE $field $fields and _require_ a [] 
sub new
{
	my( $class, $session, $dataset, $fields, $value ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{dataset} = $dataset;
	$self->set_value( $value );

	#cjg Hmmm.
	if( ref( $fields ) ne "ARRAY" )
	{
		$fields = [ $fields ];
	}

	$self->{fieldlist} = $fields;
	my( @fieldnames, @display_names );
	foreach (@{$fields})
	{
		if( !defined $_ )
		{
			#cjg an aktual error.
			exit;
		}
		push @fieldnames, $_->get_sql_name();
		push @display_names, $_->display_name( $self->{session} );
	}
	
	$self->{display_name} = join '/', @display_names;
	$self->{form_name_prefix} = join '/', sort @fieldnames;
	$self->{field} = $fields->[0];

	if( $self->{field}->get_property( "hasid" ) )
	{
		$self->{field} = $self->{field}->get_main_field();
	}
	

	return( $self );
}

## WP1: BAD
sub set_value
{
	my ( $self , $newvalue ) = @_;

	if( $newvalue =~ m/^([A-Z][A-Z][A-Z]):([A-Z][A-Z]):(.*)$/i )
	{
		$self->{value} = $newvalue;
		$self->{anyall} = uc $1;
		$self->{match} = uc $2;
		$self->{string} = $3;
	}
	else
	{
		$self->{value} = undef;
		$self->{anyall} = undef;
		$self->{match} = undef;
		$self->{string} = undef;
	}

}



######################################################################
#
# $problem = from_form()
#
#  Update the value of the field from the form. Returns any problem
#  that might have happened, or undef if everything was OK.
#
######################################################################

## WP1: BAD
sub from_form
{
	my( $self ) = @_;

	my $problem;

	# Remove any default we have
	$self->set_value( "" );
	my $val = $self->{session}->param( $self->{form_name_prefix} );
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	$val = undef if( $val eq "" );

	if( $self->is_type( "boolean" ) )
	{
		$self->set_value( "PHR:EQ:TRUE" ) if( $val eq "TRUE" );
		$self->set_value( "PHR:EQ:FALSE" ) if( $val eq "FALSE" );
	}
	elsif( $self->is_type( "email","url" ) )
	{
		# simple text types
		if( defined $val )
		{
			$self->set_value( "ANY:IN:$val" );
		}
	}
	elsif( $self->is_type( "longtext","text","name" ) )
	{
		# complex text types
		my $search_type = $self->{session}->param( 
			$self->{form_name_prefix}."_srchtype" );
		my $exact = "IN";
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$search_type = "ALL" unless defined( $search_type );		
		
		if( defined $val )
		{
			$self->set_value( "$search_type:$exact:$val" );
		}
	}		
	elsif( $self->is_type( "subject" , "set" , "datatype" ) )
	{
		my @vals = ();
		foreach( $self->{session}->param( $self->{form_name_prefix} ) )
		{
			next if m/^\s*$/;
			push @vals,$_;
		}
		my $val;
		
		if( scalar @vals > 0 )
		{
			# We have some values. Join them together.
			$val = join ' ', @vals;

			# But if one of them was the "any" option, we don't want a value.
			foreach (@vals)
			{
				undef $val if( $_ eq "NONE" );
			}

		}

		if( defined $val )
		{
			# ANY or ALL?
			my $anyall = $self->{session}->param(
				$self->{form_name_prefix}."_anyall" );
				
			$val = (defined $anyall? "$anyall" : "ANY" ).":EQ:$val";

			$self->set_value( $val );
		}

	}
	elsif( $self->is_type( "year" ) )
	{
		if( defined $val )
		{
			if( $val =~ m/^(\d\d\d\d)?\-?(\d\d\d\d)?/ )
			{
				$self->set_value( "ANY:EQ:$val" );
			}
			else
			{
				$problem = $self->{session}->phrase( "lib/searchfield:year_err" );
			}
		}
	}
	elsif( $self->is_type( "int" ) )
	{
		if( defined $val )
		{
			if( $val =~ m/^(\d+)?\-?(\d+)?/ )
			{
				$self->set_value( "ANY:EQ:$val" );
			}
			else
			{
				$problem = $self->{session}->phrase( "lib/searchfield:int_err" );
			}
		}
	}
	elsif( $self->is_type( "secret" ) )
	{
		$self->{session}->get_archive()->log( "Attempt to search a \"secret\" type field." );
	}
	else
	{
		$self->{session}->get_archive()->log( "Unknown search type: ".$self->{field}->get_type() );
	}


	return( $problem );
}
	

##########################################################
# 
# cjg commentme (all below)

## WP1: BAD
sub get_conditions 
{
	my ( $self ) = @_;

	if ( !defined $self->{value} || $self->{value} eq "" )
	{
		return undef;
	}

	my $match = $self->{match};
	if( $match eq "EX" )
	{
		# Special handling for exact matches, as it can handle NULL
		# fields, although this will not work on most multiple tables.
		my @where;
		my $sql = "__FIELDNAME__ = \"".EPrints::Database::prep_value($self->{string})."\"";
		push @where, $sql;
		if( $self->{string} eq "" )
		{	
			push @where, "__FIELDNAME__ IS NULL";
		}
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	if ( $self->is_type( "set","subject","datatype","boolean" ) )
	{
		my @fields = ();
		my $text = $self->{string};
		while( $text=~s/"([^"]+)"// ) { push @fields, $1; }
		while( $text=~s/([^\s]+)// ) { push @fields, $1; }
		my @where;
		my $field;
		foreach $field ( @fields )
		{
			my $s;
			if( $self->is_type( "subject" ) )
			{
				$s = "( __FIELDNAME__ = S.subjectid AND S.ancestors='".EPrints::Database::prep_value($field)."' )";
			} 
			else 
			{
				$s = "__FIELDNAME__ = '".EPrints::Database::prep_value($field)."'";
			}
			push @where , $s;
		}
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	if ( $self->is_type( "name" ) )
	{
		my @where = ();
		my @names = ();
		my $text = $self->{string};

		# Remove spaces before and  after commas. So Jones , C
		# is searched as Jones,C 
		$text =~ s/,\s+/,/g;
		$text =~ s/\s+,/,/g;

		# Extact names in quotes 
		while( $text=~s/"([^"]+)"// ) { push @names, $1; }

		# Extact other names
		while( $text=~s/([^\s]+)// ) { push @names, $1; }
		my $name;
		foreach $name ( @names )
		{
			$name =~ m/^([^,]+)(,(.*))?$/;
			my $family = EPrints::Database::prep_value( $1 );
			my $given = EPrints::Database::prep_value( $3 );
			if ( $self->{match} eq "IN" )
			{
				$family .= "\%";
			}
			if ( defined $given && $given ne "" )
			{
				$given .= "\%";
			}
			my $s = "__FIELDNAME___family LIKE '$family'";
			if ( defined $given && $given ne "" )
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

	if ( $self->is_type( "year","int" ) )
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

	if ( $self->is_type( "date" ) )
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

	# text, longtext, url, email:
	#
	#  word word "a phrase" word
	#

	if ( $self->is_type( "text","longtext","email","url","id" ) )
	{
		my @where = ();
		my @phrases = ();
		my $text = $self->{string};
		if ( $self->{anyall} eq "PHR" ) 
		{
			# PHRASES HAVE SPECIAL HANDLING!
			# cjg WHICH IS BROKEN!
			# If we want an exact match just return records which exactly
			# match this phrase.

			if( $self->{match} eq "EQ" )
			{
				$text = EPrints::Database::prep_value( $text );
				return ( $self->_get_conditions_aux( [ "__FIELDNAME__ = \"$text\"" ], 0 ), [] );
			}
			my( $good , $bad ) = 
				$self->{session}->get_archive()->call(
					"extract_words",
					$text );

			# If there are no useful words in the phrase, abort!
			if( scalar @{$good} == 0) {
				return(undef,undef,undef,"No indexable words in phrase \"$text\".");
			}
			foreach( @{$good} )
			{
				if( $self->{match} eq "IN" )
				{
					$_ = $self->{field}->get_name().":$_";
				}
				$_ = EPrints::Database::prep_value( $_ );
				push @where, "__FIELDNAME__ = '$_'";
			}
			return ( $self->_get_conditions_aux( \@where ,  1 ) , [] );

		}
		my $hasphrase = 0;
		while ($text =~ s/"([^"]+)"//g)
		{
			my $sfield = new EPrints::SearchField( 
				$self->{session},
				$self->{dataset},
				$self->{field},
				"PHR:IN:$1" );
			#cjg IFFY!!!!
			my ($buffer,$bad,$error) = $sfield->do( undef , undef );
			if( defined $error )
			{
				return( undef, undef, undef, $error );
			}
			push @where,$buffer; 
			$hasphrase=1;
		}
		my( $good , $bad ) = 
			$self->{session}->get_archive()->call( 
				"extract_words",
				$text );

		if( scalar @{$good} == 0 && !$hasphrase )
		{
			return(undef,undef,undef,$self->{session}->phrase( "lib/searchfield:no_words" ,  words=>$text ) );
		}

		foreach( @{$good} )
		{
			if( $self->{match} eq "IN" )
			{
				$_ = $self->{field}->get_sql_name().":$_";
			}
			$_ = EPrints::Database::prep_value( $_ );
			push @where, "__FIELDNAME__ = '$_'";
		}
		return ( $self->_get_conditions_aux( 
				\@where ,  
				$self->{match} eq "IN" ) , $bad );
	}

}

## WP1: BAD
sub _get_conditions_aux
{
	my ( $self , $wheres , $freetext ) = @_;
	my $searchtable = $self->{dataset}->get_sql_table_name();
	if ($self->{field}->{multiple}) 
	{	
		$searchtable= $self->{dataset}->get_sql_sub_table_name( $self->{field} );
	}	
	if( $freetext )
	{
		$searchtable= "!".$self->{dataset}->get_sql_index_table_name();
	}
	my $fieldname = "M.".($freetext ? "fieldword" : $self->{field}->get_sql_name() );

	my @nwheres; # normal
	my @pwheres; # pre-done
	foreach( @{$wheres} )
	{
		if( $_ =~ m/^!/ )
		{
			push @pwheres, $_;
		}
		else
		{
			s/__FIELDNAME__/$fieldname/g;
			push @nwheres, $_;
		}
	}

	if ( $self->{anyall} eq "ANY" || $self->{match} eq "EX" ) 
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

	return $searchtable.":".$self->{field}->get_name() , \@nwheres;

}

sub do
{
	my ( $self ) = @_;

	my %searches = ();
	my @sfields = ();
	my @badwords = ();

	my $field;
	foreach $field ( @{$self->{fieldlist}} ) 
	{
		my $sfield = new EPrints::SearchField( 
			$self->{session},
			$self->{dataset},
			$field,
			$self->{value} );
		my ($table,$where,$bad,$error) = $sfield->get_conditions();
		if( defined $error )
		{
			return( undef, undef, $error );
		}
		if( defined $where )
		{
			if( !defined $searches{$table} )
			{
				push @sfields,$table;
				$searches{$table}=[];
			}
			push @{$searches{$table}},@{$where};
		}
		if( defined $bad ) 
		{ 
			push @badwords, @{$bad}; 
		}
	}

	my $n = scalar @{$searches{$sfields[0]}};
	
	# I use "ne ANY" here as a fast way to mean "eq PHR" or "eq AND"
	# (phrases subsearches are always AND'd)

	my $results = [];
	my $firstpass = 1;

        my $keyfield = $self->{dataset}->get_key_field();
	my $i;
	for( $i=0 ; $i<$n ; ++$i )
	{
		my $bitresults = [];
		my $tablename;
		foreach $tablename ( @sfields )
		{
			my $tname = $tablename;
			my $where = $searches{$tablename}->[$i];

			# Tables have a colon and fieldname after them
			# to make sure references to different fields are
			# still kept seperate. But we don't want to pass
			# this to the SQL.
			$tname =~ s/:.*//;
	
			my $r;
#phrases: a pre done set, than a LOIKE? cjg
			if( ref( $where ) eq "ARRAY" )
			{
				# search has already been done, just pass
				# resulys along
				$r = $where;
			}
			elsif( $tname=~s/^!// )
			{
				# Free text search
				$r = $self->{session}->get_db()->get_index_ids( $tname, $where );
			}	
			else
			{ 
				# Normal Search
				my $tables = {};
				$tables->{M} = $tname;
				if( $self->{field}->is_type( "subject" ) && $self->{match} ne "EX" )
				{
					# maybe we should calculate this
					# tablename from dataset? for added
					# robusty goodness.
					$tables->{S} = "subject_ancestors";
				}
				$r = $self->{session}->get_db()->search( $keyfield, $tables, $where );
			}
			$bitresults = EPrints::SearchExpression::_merge( $r , $bitresults, 0 );
		}
		if( $firstpass )
		{
			$results = $bitresults;
		}	
		else
		{
			$results = EPrints::SearchExpression::_merge( $bitresults, $results, ( $self->{anyall} ne "ANY" ) );
		}
		$firstpass = 0;
	}
	return( $results, \@badwords );
}


sub get_value
{
	my( $self ) = @_;
	return $self->{value};
}

#returns the FIRST field which should indicate type and stuff.
sub get_field
{
	my( $self ) = @_;
	return $self->{field};
}
sub get_fields
{
	my( $self ) = @_;
	return $self->{fieldlist};
}


######################################################################
#
# $html = render()
#
#
######################################################################

## WP1: BAD
sub render
{
	my( $self ) = @_;

	my $query = $self->{session}->get_query();
	
	my @set_tags = ( "ANY", "ALL" );
	my %set_labels = ( 
		"ANY" => $self->{session}->phrase( "lib/searchfield:set_any" ),
		"ALL" => $self->{session}->phrase( "lib/searchfield:set_all" ) );

	my @text_tags = ( "ALL", "ANY" );
	my %text_labels = ( 
		"ANY" => $self->{session}->phrase( "lib/searchfield:text_any" ),
		"ALL" => $self->{session}->phrase( "lib/searchfield:text_all" ) );

	my @bool_tags = ( "EITHER", "TRUE", "FALSE" );
	my %bool_labels = ( "EITHER" => $self->{session}->phrase( "lib/searchfield:bool_nopref" ),
		            "TRUE"   => $self->{session}->phrase( "lib/searchfield:bool_yes" ),
		            "FALSE"  => $self->{session}->phrase( "lib/searchfield:bool_no" ) );

#cjg NO DATE SEARCH!!!
	my $frag = $self->{session}->make_doc_fragment();
	
	if( $self->is_type( "boolean" ) )
	{
		# Boolean: Popup menu
	
		$frag->appendChild( 
			$self->{session}->render_option_list(
				name => $self->{form_name_prefix},
				values => \@bool_tags,
				default => ( defined $self->{string} ? $self->{string} : $bool_tags[0] ),
				labels => \%bool_labels ) );
	}
	elsif( $self->is_type( "boolean","longtext","text","name","url","id","email" ) )
	{
		# complex text types
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $self->{form_name_prefix},
				value => $self->{string},
#cjg Number for form width1
				size => $EPrints::HTMLRender::search_form_width,
				maxlength => $EPrints::HTMLRender::field_max ) );
		$frag->appendChild( $self->{session}->make_text(" ") );
		$frag->appendChild( 
			$self->{session}->render_option_list(
				name=>$self->{form_name_prefix}."_srchtype",
				values=>\@text_tags,
				value=>$self->{anyall},
				labels=>\%text_labels ) );
	}
	elsif( $self->is_type( "datatype" , "set" , "subject" ) )
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

		my %settings = (
			name => $self->{form_name_prefix},
			default => \@defaults,
			multiple => "multiple" );
		
		if( $self->is_type( "subject" ) )
		{
			# WARNING: passes in {} as a dummy user. May need to change this
			# if the "postability" algorithm checks user info. cjg
			my $topsubj = EPrints::Subject->new(
				$self->{session},
				$self->{field}->get_property( "top" ) );
			my ( $pairs ) = $topsubj->get_subjects( 0, 0 );
			#splice( @{$pairs}, 0, 0, [ "NONE", "(Any)" ] ); #cjg
			$settings{pairs} = $pairs;
			$settings{size} = ( 
#cjg Number for form dfefaults
				scalar @$pairs > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$pairs );
		}
		else
		{
			my( $tags, $labels );
			if( $self->is_type( "datatype" ) )
			{
				my $ds = $self->{session}->get_archive()->get_dataset(
                                        	$self->{field}->get_property( "datasetid" ) );
				$tags = $ds->get_types();
				$labels = $ds->get_type_names( $self->{session} );
			}
			else # type is "set"
			{
				( $tags, $labels ) = $self->{field}->tags_and_labels( $self->{session} );
			}
		
			$settings{labels} = $labels;
			$settings{values} = $tags;
			$settings{size} = ( 
#form defaults
				scalar @$tags > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$tags );
		}	

		$frag->appendChild( $self->{session}->render_option_list( %settings ) );

		if( $self->{field}->get_property( "multiple" ) )
		{
			$frag->appendChild( $self->{session}->make_text(" ") );
			$frag->appendChild( 
				$self->{session}->render_option_list(
					name=>$self->{form_name_prefix}."_self->{anyall}",
					values=>\@set_tags,
					value=>$self->{anyall},
					labels=>\%set_labels ) );
		}
	}
	elsif( $self->is_type( "int" ) )
	{
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$self->{form_name_prefix},
				value=>$self->{string},
				size=>9,
				maxlength=>100 ) );
	}
	elsif( $self->is_type( "year" ) )
	{
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$self->{form_name_prefix},
				value=>$self->{string},
				size=>9,
				maxlength=>9 ) );
	}
	else
	{
		$self->{session}->get_archive()->log( "Can't Render: ".$self->{field}->get_type() );
	}
	return $frag;
}

## WP1: BAD
sub get_help
{
        my( $self ) = @_;

        return $self->{session}->phrase( "lib/searchfield:help_".$self->{field}->get_type() );
}

## WP1: BAD
sub is_type
{
	my( $self, @types ) = @_;
	return $self->{field}->is_type( @types );
}

## WP1: BAD
sub get_display_name
{
	my( $self ) = @_;
	return $self->{display_name};
}

sub get_form_name
{
	my( $self ) = @_;
	return $self->{form_name_prefix};
}

sub is_set
{
	my( $self ) = @_;

	return EPrints::Utils::is_set( $self->{string} ) || $self->{match} eq "EX";
}

sub serialise
{
	my( $self ) = @_;

	return undef unless( $self->is_set() );

	# cjg. Might make an teeny improvement if
	# we sorted the {string} so that equiv. searches
	# have the same serialisation string.

	my @fnames;
	foreach( @{$self->{fieldlist}} )
	{
		push @fnames, $_->get_name().($_->get_property( "idpart" )?".id":"");
	}
	
	my @escapedparts;
	foreach(join( "/", sort @fnames ),
		$self->{anyall}, 	
		$self->{match}, 
		$self->{string} )
	{
		my $item = $_;
		$item =~ s/[\\\:]/\\$&/g;
		push @escapedparts, $item;
	}
	return join( ":" , @escapedparts );
}

sub unserialise
{
	my( $class, $session, $dataset, $string ) = @_;

	my @parts = split( ":", $string );
	# Un-escape
	foreach( @parts ) { s/\\(.)/$1/g; }

	#cjg sick lose this dreadful "value"
	my $value = "$parts[1]:$parts[2]:$parts[3]";
	my @fields = ();
	foreach( split( "/" , $parts[0] ) )
	{
		push @fields, $dataset->get_field( $_ );
	}
	
	return $class->new( $session, $dataset, \@fields, $value );
}

# only really meaningful to move between eprint datasets
sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{dataset} = $dataset;
}
1;
