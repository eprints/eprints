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
#  XXXX & datatype        "poss1:poss2:poss3"
#  longtext, text & name   "[all][any][phr]:terms"
#  username, set & subject  "val1:val2:val3:[ANY|ALL]"
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
sub new
{
	my( $class, $session, $dataset, $field, $value ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{dataset} = $dataset;
print STDERR "TID: $dataset\n";
	$self->set_value( $value );

		
	if( ref( $field ) eq "ARRAY" )
	{
		# Search >1 field
		$self->{multifields} = $field;
		my( @fieldnames, @displaynames );
		foreach (@{$field})
		{
if( !defined $_ )
{
	EPrints::Session::bomb();
}
			push @fieldnames, $_->get_name();
			push @displaynames, $_->display_name( $self->{session} );
		}
	
		$self->{displayname} = join '/', @displaynames;
		$self->{formname} = join '_', @fieldnames;
		$self->{field} = $field->[0];
	}
	else
	{
		$self->{field} = $field;
if( !defined $field ) { &EPrints::Session::bomb; }

		$self->{displayname} = $field->display_name( $self->{session} );
		$self->{formname} = $field->get_name();
	}
	

	return( $self );
}

## WP1: BAD
sub set_value
{
	my ( $self , $newvalue ) = @_;


print STDERR "set_value( $newvalue )\n";

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

	# Value has changed. Previous benchmarks no longer apply.
	$self->{benchcache} = {};

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
#print STDERR "------llll\n";	
#print STDERR  $self->{formname} ."\n";
#print STDERR  $self->{field}->{type}."\n";
#print STDERR  $self->{session}->param( $self->{formname} )."\n";
	my $val = $self->{session}->param( $self->{formname} );
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	$val = undef if( $val eq "" );

	if( $self->is_type( "boolean" ) )
	{
		$self->set_value( "PHR:EQ:$val" ) if( $val ne "EITHER" );
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
			$self->{formname}."_srchtype" );
		my $exact = "IN";
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$search_type = "ALL" unless defined( $search_type );		
		
		if( defined $val )
		{
			$self->set_value( "$search_type:$exact:$val" );
		}
	}		
	elsif( $self->is_type( "username" ) )
	{
		# usernames
		my $anyall = $self->{session}->param( 
			$self->{formname}."_anyall" );
		
		# Default search type if none supplied (to allow searches using simple
		# HTTP GETs)
		$anyall = "ALL" unless defined( $anyall );		
		my $exact = "IN";
	
		my @vals = split /\s+/ , $val;
		if( scalar @vals > 0)
		{
			$self->set_value( "$anyall:$exact:".join( " " , @vals ) );
		}
	}		
	elsif( $self->is_type( "subject" , "set" , "datatype" ) )
	{
		my @vals = ();
		foreach( $self->{session}->param( $self->{formname} ) )
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
				$self->{formname}."_anyall" );
				
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
	else
	{
		$self->{session}->get_archive()->log( "Unknown search type." );
	}


	return( $problem );
}
	

##########################################################
# 
# cjg commentme (all below)

## WP1: BAD
sub get_conditions 
{
	my ( $self , $benchmarking ) = @_;

	if ( !defined $self->{value} || $self->{value} eq "" )
	{
		return undef;
	}

	if ( $self->is_type( "set","subject","datatype","boolean","username" ) )
	{
		my @fields = ();
		my $text = $self->{string};
		while( $text=~s/"([^"]+)"// ) { push @fields, $1; }
		while( $text=~s/([^\s]+)// ) { push @fields, $1; }
		my @where;
		my $field;
		foreach $field ( @fields )
		{
			my $s = "__FIELDNAME__ = '".EPrints::Database::prep_value($field)."'";
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

	if ( $self->is_type( "text","longtext","email","url" ) )
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
					$_ = "$self->{field}->{name}:$_";
				}
				$_ = EPrints::Database::prep_value( $_ );
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
					$self->{dataset},
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
			$self->{session}->get_archive()->call( 
				"extract_words",
				$text );

		if( scalar @{$good} == 0 && !$hasphrase )
		{
			return(undef,undef,undef,$self->{session}->phrase( "lib/searchfield:no_words" , { words=>$text } ) );
		}

		foreach( @{$good} )
		{
			if( $self->{match} eq "IN" )
			{
				$_ = "$self->{field}->{name}:$_";
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
print STDERR "ack\n";
	}	
	if( $freetext )
	{
		$searchtable= $self->{dataset}->get_sql_index_table_name();
print STDERR "ock\n";
	}

	my $fieldname = "M.".($freetext ? "fieldword" : $self->{field}->get_name() );

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

## WP1: BAD
sub benchmark
{
	my ( $self , $tablefield , $where ) = @_;

	my( $table , $field ) = split /:/ , $tablefield;

        my $keyfield = $self->{dataset}->get_key_field();

	if ( !defined $self->{benchcache}->{"$table:$where"} )
	{
		$self->{benchcache}->{"$table:$where"} = 
			$self->{session}->{database}->benchmark( 
				$keyfield,
				{ "M"=>$table }, 
				$where );
	}
	return $self->{benchcache}->{"$table:$where"};

}

# benchmarking means that we only need to get approx 
# results from this...

## WP1: BAD
sub _get_tables_searches
{
	my ( $self , $benchmarking) = @_;

	my %searches = ();
	my @tables = ();
	my @badwords = ();
	if( defined $self->{multifields} )
	{
		my $multifield;
		foreach $multifield ( @{$self->{multifields}} ) 
		{
			my $sfield = new EPrints::SearchField( 
				$self->{session},
				$self->{dataset},
				$multifield,
				$self->{value} );
			my ($table,$where,$bad,$error) = 
				$sfield->get_conditions( $benchmarking );
			if( defined $error )
			{
				return( undef, undef, undef, $error );
			}
			if( defined $where )
			{
				if( !defined $searches{$table} )
				{
					push @tables,$table;
					$searches{$table}=[];
				}
	print STDERR "[$searches{$table}][$table][$where][$bad][$error][$sfield->{field}->{name}][$benchmarking]\n";
				push @{$searches{$table}},@{$where};
			}
			if( defined $bad ) 
			{ 
				push @badwords, @{$bad}; 
			}
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

## WP1: BAD
sub do
{
	my ( $self , $searchbuffer , $satisfy_all) = @_;
	
        my $keyfield = $self->{dataset}->get_key_field();

	my ($sfields, $searches, $badwords, $error) = $self->_get_tables_searches();
	if( defined $error ) 
	{
		return ( undef , undef , $error );
	}
	if( !defined $sfields || !defined $sfields->[0] )
	{
		return $searchbuffer;
	}
	my $n = scalar @{$searches->{$sfields->[0]}};
	
	#my @forder = sort { $self->benchmark($table,$a) <=> $self->benchmark($table,$b) } @{$where};

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

	for( $i=0 ; $i<$n ; ++$i )
	{
		my $nextbuffer 	= undef;
		my $tablename 	= undef;
		foreach $tablename ( @{$sfields} )
		{
			my $where = $searches->{$tablename}->[$i];

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
		}
		$buffer = $nextbuffer;
	}
	if( $self->{anyall} eq "PHR"  && $self->{anyall} eq "IN" )
	{
		print STDERR "==================================\nRIGHT NOW $self->{string}\n==============\n";
		my( $tablefield , $wheres ) = $self->_get_conditions_aux( 
						[ "__FIELDNAME__ LIKE \"\%".
						  EPrints::Database::prep_value( $self->{string} )."\%\"" ] , 
						  0 );
		my $table = $tablefield;
		$table=~s/:.*//;
		my $tlist = { "M"=>$table };
		$buffer = $self->{session}->{database}->buffer( 
			$keyfield,
			$tlist, 
			${$wheres}[0],
			undef );
	}

	if( $self->{anyall} ne "ANY" && !$satisfy_all )
	{
		$buffer = $self->{session}->{database}->buffer( 
			$keyfield,
			{ "T"=>$buffer },
			undef,
			$searchbuffer );
	}

	return ( $buffer, $badwords );

}

## WP1: BAD
sub approx_rows 
{
	my ( $self ) = @_;

	my ($tables, $searches, $badwords, $error) = $self->_get_tables_searches( 1 );

	if( defined $error )
	{
		return 0;
	}
	if( !defined $tables || !defined $tables->[0] )
	{
		return 0;
	}
	my $n = scalar @{$searches->{$tables->[0]}};

	my $result = undef;
	my $i;
	for( $i=0 ; $i<$n ; ++$i )
	{
		my $i_result = undef;
		my $table;
		foreach $table ( @{$tables} )
		{
			my $rows = $self->benchmark( $table , $searches->{$table}->[$i] ); 
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

	return $result;
}


## WP1: BAD
sub get_field
{
	my( $self ) = @_;
	return $self->{field};
}

######################################################################
#
# $html = to_html()
#
#
######################################################################

## WP1: BAD
sub to_html
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
				name => $self->{formname},
				values => \@bool_tags,
				default => ( defined $self->{string} ? $self->{string} : $bool_tags[0] ),
				labels => \%bool_labels ) );
	}
	elsif( $self->is_type( "boolean","longtext","text","name","url","username" ) )
	{
		# complex text types
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $self->{formname},
				value => $self->{string},
				size => $EPrints::HTMLRender::search_form_width,
				maxlength => $EPrints::HTMLRender::field_max ) );
		$frag->appendChild( $self->{session}->make_text(" ") );
		$frag->appendChild( 
			$self->{session}->render_option_list(
				name=>$self->{formname}."_srchtype",
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

		# Make a list of possible values
		my( $tags, $labels );
		
		if( $self->is_type( "subject" ) )
		{
			# WARNING: passes in {} as a dummy user. May need to change this
			# if the "postability" algorithm checks user info.
			( $tags, $labels ) = EPrints::Subject::get_postable( $self->{session}, {} );
		}
		elsif( $self->is_type( "datatype" ) )
		{
			my $ds = $self->{session}->get_archive()->get_dataset(
                                        $self->{field}->get_property( "datasetid" ) );
			$tags = $ds->get_types();
			$labels = $ds->get_type_names( $self->{session} );
		}
		else
		{
			# set
			( $tags, $labels ) = $self->{field}->tags_and_labels( $self->{session} );
		}
	
		my( $old_tags, $old_labels ) = ( $tags, $labels );

		$tags = [ "NONE" ];

		# we have to copy the tags and labels as they are currently
		# references to the origionals. 
	
		push @{$tags}, @{$old_tags};
		$labels->{NONE} = "(Any)";

		$frag->appendChild( $self->{session}->render_option_list(
			name => $self->{formname},
			values => $tags,
			default => \@defaults,
			size=>( scalar @$tags > $EPrints::HTMLRender::list_height_max ?
				$EPrints::HTMLRender::list_height_max :
				scalar @$tags ),
			multiple => "multiple",
			labels => $labels ) );

		if( $self->{multiple} )
		{
			$frag->appendChild( $self->{session}->make_text(" ") );
			$frag->appendChild( 
				$self->{session}->render_option_list(
					name=>$self->{formname}."_self->{anyall}",
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
				name=>$self->{formname},
				value=>$self->{string},
				size=>9,
				maxlength=>100 ) );
	}
	elsif( $self->is_type( "year" ) )
	{
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$self->{formname},
				value=>$self->{string},
				size=>9,
				maxlength=>9 ) );
	}
	else
	{
		$self->{session}->get_archive()->log( "Can't Render: ".$self->get_type() );
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
	return $self->{displayname};
}

## WP1: BAD
sub get_form_name
{
	my( $self ) = @_;
	return $self->{formname};
}

## WP1: BAD
sub get_value
{
	my( $self ) = @_;

	if( $self->{value} eq "")
	{
		return undef;
	}

	return $self->{value};
}

1;
