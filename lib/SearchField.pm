######################################################################
#
# EPrints::SearchField
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

B<EPrints::SearchField> - undocumented

=head1 DESCRIPTION

undocumented

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $self->{foo}
#     undefined
#
######################################################################

#####################################################################
#
#  Search Field
#
#   Represents a single field in a search.
#
######################################################################
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

#cjg MAKE $field $fields and _require_ a [] 

######################################################################
=pod

=item $thing = EPrints::SearchField->new( $session, $dataset, $fields, $value, $match, $merge, $prefix )

undocumented

Special case - if match is "EX" and field type is name then value must
be a name hash.

=cut
######################################################################

sub new
{
	my( $class, $session, $dataset, $fields, $value, $match, $merge, $prefix ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{session} = $session;
	$self->{dataset} = $dataset;

	$self->{value} = $value;
	$self->{match} = ( defined $match ? $match : "EQ" );
	$self->{merge} = ( defined $merge ? $merge : "PHR" );

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

	$prefix = "" unless defined $prefix;
		
	$self->{display_name} = join '/', @display_names;
	$self->{id} = join '/', sort @fieldnames;
	$self->{form_name_prefix} = $prefix.$self->{id};
	$self->{field} = $fields->[0];

	if( $self->{field}->get_property( "hasid" ) )
	{
		$self->{field} = $self->{field}->get_main_field();
	}

	return( $self );
}


######################################################################
=pod

=item $foo = $sf->clear

undocumented

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	$self->{match} = "NO";
}

######################################################################
#
# $problem = from_form()
#
#  Update the value of the field from the form. Returns any problem
#  that might have happened, or undef if everything was OK.
#
######################################################################


######################################################################
=pod

=item $foo = $sf->from_form

undocumented

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $problem;

	# Remove any default we have
	$self->clear();

	my $val = $self->{session}->param( $self->{form_name_prefix} );
	$val =~ s/^\s+//;
	$val =~ s/\s+$//;
	$val = undef if( $val eq "" );

	if( $self->is_type( "boolean" ) )
	{
		$self->{merge} = "PHR";
		$self->{match} = "EQ";
		$self->{value} = "FALSE" if( $val eq "FALSE" );
		$self->{value} = "TRUE" if( $val eq "TRUE" );
	}
	elsif( $self->is_type( "email","url" ) )
	{
		if( defined $val )
		{
			$self->{merge} = "ANY";
			$self->{match} = "IN";
			$self->{value} = $val;
		}
	}
	elsif( $self->is_type( "longtext","text","name" ) )
	{
		# complex text types
		my $search_type = $self->{session}->param( 
			$self->{form_name_prefix}."_srchtype" );
		
		# Default search type if none supplied (to allow searches 
		# using simple HTTP GETs)
		$search_type = "ALL" unless defined( $search_type );		
		
		if( defined $val )
		{
			$self->{match} = "IN";
			$self->{merge} = $search_type;
			$self->{value} = $val;
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
			my $merge = $self->{session}->param(
				$self->{form_name_prefix}."_merge" );
			$self->{merge} = defined $merge? "$merge" : "ANY";
			$self->{match} = "EQ";
			$self->{value} = $val;
		}

	}
	elsif( $self->is_type( "year" ) )
	{
		if( defined $val )
		{
			if( $val =~ m/^(\d\d\d\d)?\-?(\d\d\d\d)?/ )
			{
				$self->{merge} = ""; # not used
				$self->{match} = "EQ";
				$self->{value} = $val;
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
				$self->{merge} = ""; # not used
				$self->{match} = "EQ";
				$self->{value} = $val;
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


######################################################################
=pod

=item $foo = $sf->get_conditions 

undocumented

=cut
######################################################################

sub get_conditions 
{
	my ( $self ) = @_;

	return if( $self->{match} eq "NO" );

	my $match = $self->{match};

	# Special handling for exact matches, as it can handle NULL
	# fields, although this will not work on most multiple tables.
	if( $match eq "EX" )
	{
		my @where;

		# Special Special handling for exact matches on names
		if ( $self->is_type( "name" ) )
		{
			my @s = ();
			foreach( "honourific", "given", "family", "lineage" )
			{
				my $v = $self->{value}->{$_};
				push @s,"__FIELDNAME___".$_." = ".
		"\"".EPrints::Database::prep_value($v)."\"";
			}
			push @where , "(".join( " AND ",@s ).")";
		}
		else
		{
			my $sql = "__FIELDNAME__ = \"".EPrints::Database::prep_value($self->{value})."\"";
			push @where, $sql;
			if( $self->{value} eq "" )
			{	
				push @where, "__FIELDNAME__ IS NULL";
			}
		}
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	if ( $self->is_type( "set","subject","datatype","boolean" ) )
	{
		my @fields = ();
		my $text = $self->{value};
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
		my $text = $self->{value};

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
			my $family = EPrints::Database::prep_like_value( $1 );
			my $given = EPrints::Database::prep_like_value( $3 );
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
		foreach( split /\s+/ , $self->{value} )
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
				return( undef,undef,$error);
			}
			push @where, $sql;
		}
		return( $self->_get_conditions_aux( \@where , 0) );
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
		foreach( split /\s+/ , $self->{value} )
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
				return( undef,undef,$error);
			}
			push @where, $sql;
		}
		return( $self->_get_conditions_aux( \@where , 0) );
	}

	# text, longtext, url, email:
	#
	#  word word "a phrase" word
	#

	if ( $self->is_type( "text","longtext","email","url","id" ) )
	{
		my @where = ();
		my @phrases = ();
		my $text = $self->{value};
		if ( $self->{merge} eq "PHR" ) 
		{
			# PHRASES HAVE SPECIAL HANDLING!
			# cjg WHICH IS BROKEN!
			# If we want an exact match just return records which exactly
			# match this phrase.

			if( $self->{match} eq "EQ" )
			{
				$text = EPrints::Database::prep_value( $text );
				return ( $self->_get_conditions_aux( [ "__FIELDNAME__ = \"$text\"" ], 0 ) );
			}
			my( $good , $bad ) = 
				$self->{session}->get_archive()->call(
					"extract_words",
					$text );

			# If there are no useful words in the phrase, abort!
			if( scalar @{$good} == 0) {
				return(undef,undef,"No indexable words in phrase \"$text\".");
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
			return $self->_get_conditions_aux( \@where ,  1 );

		}
		my $hasphrase = 0;
		while ($text =~ s/"([^"]+)"//g)
		{
			my $sfield = new EPrints::SearchField( 
				$self->{session},
				$self->{dataset},
				$self->{field},
				$1,
				"IN",
				"PHR" );
			#cjg IFFY!!!!
			my ($buffer,$error) = $sfield->do( undef , undef );
			if( defined $error )
			{
				return( undef, undef, $error );
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
			return(undef,undef,$self->{session}->phrase( "lib/searchfield:no_words" ,  words=>$text ) );
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
				$self->{match} eq "IN" ) );
	}

}

######################################################################
# 
# $foo = $sf->_get_conditions_aux( $wheres, $freetext )
#
# undocumented
#
######################################################################

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

	if ( $self->{merge} eq "ANY" || $self->{match} eq "EX" ) 
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


######################################################################
=pod

=item $foo = $sf->do

undocumented

=cut
######################################################################

sub do
{
	my ( $self ) = @_;

	my %searches = ();
	my @sfields = ();

	my $field;
	foreach $field ( @{$self->{fieldlist}} ) 
	{
		my $sfield = new EPrints::SearchField( 
			$self->{session},
			$self->{dataset},
			$field,
			$self->{value},
			$self->{match},
			$self->{merge} );
		my ($table,$where,$error) = $sfield->get_conditions();
		if( defined $error )
		{
			return( undef, $error );
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
			$results = EPrints::SearchExpression::_merge( $bitresults, $results, ( $self->{merge} ne "ANY" ) );
		}
		$firstpass = 0;
	}
	return( $results );
}


######################################################################
=pod

=item $foo = $sf->get_value

undocumented

=cut
######################################################################

sub get_value
{
	my( $self ) = @_;

	return $self->{value};
}


######################################################################
=pod

=item $foo = $sf->get_match

undocumented

=cut
######################################################################

sub get_match
{
	my( $self ) = @_;

	return $self->{match};
}


######################################################################
=pod

=item $foo = $sf->get_merge

undocumented

=cut
######################################################################

sub get_merge
{
	my( $self ) = @_;

	return $self->{merge};
}



#returns the FIRST field which should indicate type and stuff.

######################################################################
=pod

=item $foo = $sf->get_field

undocumented

=cut
######################################################################

sub get_field
{
	my( $self ) = @_;
	return $self->{field};
}

######################################################################
=pod

=item $foo = $sf->get_fields

undocumented

=cut
######################################################################

sub get_fields
{
	my( $self ) = @_;
	return $self->{fieldlist};
}




######################################################################
=pod

=item $xhtml = $sf->render

Returns an XHTML tree of this search field which contains all the 
input boxes required to search this field. 

=cut
######################################################################

sub render
{
	my( $self, $prefix ) = @_;

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
				default => ( defined $self->{value} ? $self->{value} : $bool_tags[0] ),
				labels => \%bool_labels ) );
	}
	elsif( $self->is_type( "longtext","text","name","url","id","email" ) )
	{
		# complex text types
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				type => "text",
				name => $self->{form_name_prefix},
				value => $self->{value},
				size => $self->{field}->get_property( "search_cols" ),
				maxlength => 256 ) );
		$frag->appendChild( $self->{session}->make_text(" ") );
		$frag->appendChild( 
			$self->{session}->render_option_list(
				name=>$self->{form_name_prefix}."_srchtype",
				values=>\@text_tags,
				default=>$self->{merge},
				labels=>\%text_labels ) );
	}
	elsif( $self->is_type( "datatype" , "set" , "subject" ) )
	{
		my @defaults;
		my $max_rows =  $self->{field}->get_property( "search_rows" );
		
		# Do we have any values already?
		if( defined $self->{value} && $self->{value} ne "" )
		{
			@defaults = split /\s/, $self->{value};
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
			
			my $topsubj = $self->{field}->get_top_subject(
				$self->{session} );
			my ( $pairs ) = $topsubj->get_subjects( 0, 0 );
			#splice( @{$pairs}, 0, 0, [ "NONE", "(Any)" ] ); #cjg
			$settings{pairs} = $pairs;
			$settings{height} = ( 
				scalar @$pairs > $max_rows ?
				$max_rows :
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
			$settings{height} = ( 
				scalar @$tags > $max_rows ?
				$max_rows :
				scalar @$tags );
		}	

		$frag->appendChild( $self->{session}->render_option_list( %settings ) );

		if( $self->{field}->get_property( "multiple" ) )
		{
			$frag->appendChild( $self->{session}->make_text(" ") );
			$frag->appendChild( 
				$self->{session}->render_option_list(
					name=>$self->{form_name_prefix}."_self->{merge}",
					values=>\@set_tags,
					value=>$self->{merge},
					labels=>\%set_labels ) );
		}
	}
	elsif( $self->is_type( "int" ) )
	{
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$self->{form_name_prefix},
				value=>$self->{value},
				size=>9,
				maxlength=>100 ) );
	}
	elsif( $self->is_type( "year" ) )
	{
		$frag->appendChild(
			$self->{session}->make_element( "input",
				"accept-charset" => "utf-8",
				name=>$self->{form_name_prefix},
				value=>$self->{value},
				size=>9,
				maxlength=>9 ) );
	}
	else
	{
		$self->{session}->get_archive()->log( "Can't Render: ".$self->{field}->get_type() );
	}
	return $frag;
}

######################################################################
=pod

=item $xhtml = $sf->render_description

Returns an XHTML DOM object describing this field and its current
settings.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	my $phraseid;
	if( $self->{match} eq "EQ" || $self->{match} eq "EX" )
	{
		$phraseid = "lib/searchfield:desc_is";
	}
	else
	{
		# match = "IN"
		if( $self->{merge} eq "ANY" )
		{
			$phraseid = "lib/searchfield:desc_any_in";
		}
		else
		{
			$phraseid = "lib/searchfield:desc_all_in";
		}
	}

	my $valuedesc = $self->{session}->make_doc_fragment;
	if( $self->is_type( "datatype", "set", "subject" ) )
	{
		if( $self->{merge} eq "ANY" )
		{
			$phraseid = "lib/searchfield:desc_any_in";
		}
		else
		{
			$phraseid = "lib/searchfield:desc_all_in";
		}
		my @list = split( / /,  $self->{value} );
		for( my $i=0; $i<scalar @list; ++$i )
		{
			if( $i>0 )
			{
				$valuedesc->appendChild( 
					$self->{session}->make_text( ", " ) );
			}
			$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );
			$valuedesc->appendChild(
				$self->{field}->get_value_label(
					$self->{session},
					$list[$i] ) );
			$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );

		}
	}
	elsif( $self->is_type( "year", "int" ) )
	{
		my $type = $self->{field}->get_type;
		if( $self->{value} =~ m/^([0-9]+)-([0-9]+)$/ )
		{
			$valuedesc->appendChild( $self->{session}->html_phrase(
				"lib/searchfield:desc_".$type."_between",
				from => $self->{session}->make_text( $1 ),
				to => $self->{session}->make_text( $2 ) ) );
		}
		elsif( $self->{value} =~ m/^-([0-9]+)$/ )
		{
			$valuedesc->appendChild( $self->{session}->html_phrase(
				"lib/searchfield:desc_".$type."_orless",
				to => $self->{session}->make_text( $1 ) ) );
		}
		elsif( $self->{value} =~ m/^([0-9]+)-$/ )
		{
			$valuedesc->appendChild( $self->{session}->html_phrase(
				"lib/searchfield:desc_".$type."_ormore",
				from => $self->{session}->make_text( $1 ) ) );
		}
		else
		{
			$valuedesc->appendChild( $self->{session}->make_text(
				$self->{value} ) );
		}
	}
	elsif( $self->is_type( "email", "url", "text" , "longtext" ) )
	{
		$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );
		$valuedesc->appendChild( 
			$self->{session}->make_text( $self->{value} ) );
		$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );
		my( $good , $bad ) = $self->{session}->get_archive()->call(
				"extract_words",
				$self->{value} );

		if( scalar(@{$bad}) )
		{
			my $igfrag = $self->{session}->make_doc_fragment;
			for( my $i=0; $i<scalar(@{$bad}); $i++ )
			{
				if( $i>0 )
				{
					$igfrag->appendChild(
						$self->{session}->make_text( 
							', ' ) );
				}
				$igfrag->appendChild(
					$self->{session}->make_text( 
						'"'.$bad->[$i].'"' ) );
			}
			$valuedesc->appendChild( 
				$self->{session}->html_phrase( 
					"lib/searchfield:desc_ignored",
					list => $igfrag ) );
		}
	}
	elsif( $self->is_type( "boolean" ) )
	{
		if( $self->{value} eq "TRUE" )
		{
			$phraseid = "lib/searchfield:desc_true";
		}
		else
		{
			$phraseid = "lib/searchfield:desc_false";
		}
	}
	elsif( $self->is_type( "name" ) )
	{
		$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );
		$valuedesc->appendChild( 
			$self->{session}->make_text( 
				$self->{value} ) );
		$valuedesc->appendChild(
				$self->{session}->make_text( '"' ) );
	}
	else
	{
		$valuedesc->appendChild( 
			$self->{session}->make_text( 
				"(not sure how to describe) ".
				$self->{value} ) );
	}

	$frag->appendChild( $self->{session}->html_phrase(
		$phraseid,
		name => $self->{session}->make_text( $self->{display_name} ),
		value => $valuedesc ) ); 

###int,year,
###datatype,set,subjcet

#id?,search?
	return $frag;
}


######################################################################
=pod

=item $foo = $sf->get_help

undocumented

=cut
######################################################################

sub get_help
{
        my( $self ) = @_;

        return $self->{session}->phrase( "lib/searchfield:help_".$self->{field}->get_type() );
}


######################################################################
=pod

=item $foo = $sf->is_type( @types )

undocumented

=cut
######################################################################

sub is_type
{
	my( $self, @types ) = @_;
	return $self->{field}->is_type( @types );
}


######################################################################
=pod

=item $foo = $sf->get_display_name

undocumented

=cut
######################################################################

sub get_display_name
{
	my( $self ) = @_;
	return $self->{display_name};
}


######################################################################
=pod

=item $foo = $sf->get_id

undocumented

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{id};
}


######################################################################
=pod

=item $foo = $sf->is_set

undocumented

=cut
######################################################################

sub is_set
{
	my( $self ) = @_;

	return EPrints::Utils::is_set( $self->{value} ) || $self->{match} eq "EX";
}


######################################################################
=pod

=item $foo = $sf->serialise

undocumented

=cut
######################################################################

sub serialise
{
	my( $self ) = @_;

	return undef unless( $self->is_set() );

	# cjg. Might make an teeny improvement if
	# we sorted the {value} so that equiv. searches
	# have the same serialisation string.

	my @fnames;
	foreach( @{$self->{fieldlist}} )
	{
		push @fnames, $_->get_name().($_->get_property( "idpart" )?".id":"");
	}
	
	my @escapedparts;
	foreach(join( "/", sort @fnames ),
		$self->{merge}, 	
		$self->{match}, 
		$self->{value} )
	{
		my $item = $_;
		$item =~ s/[\\\:]/\\$&/g;
		push @escapedparts, $item;
	}
	return join( ":" , @escapedparts );
}


######################################################################
=pod

=item $thing = EPrints::SearchField->unserialise( $session, $dataset, $string )

undocumented

=cut
######################################################################

sub unserialise
{
	my( $class, $session, $dataset, $string ) = @_;

	$string=~m/^([^:]*):([^:]*):([^:]*):(.*)$/;
	my( $fields, $merge, $match, $value ) = ( $1, $2, $3, $4 );
	# Un-escape (cjg, not very tested)
	$value =~ s/\\(.)/$1/g;

	my @fields = ();
	foreach( split( "/" , $fields ) )
	{
		push @fields, $dataset->get_field( $_ );
	}

	return $class->new( $session, $dataset, \@fields, $value, $match, $merge );
}

# only really meaningful to move between eprint datasets
# could be dangerous later with complex datasets.
# currently only used by the OAI code.

######################################################################
=pod

=item $foo = $sf->set_dataset( $dataset )

undocumented

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{dataset} = $dataset;
}




######################################################################
=pod

=item $boolean = $thing->item_matches( $item );

undocumented

=cut
######################################################################

sub item_matches
{
	my( $self, $item ) = @_;

	return( 0 ) if( $self->{match} eq "NO" );

	my @list = ();
	foreach my $field ( @{$self->{fieldlist}} ) 
	{
		push @list, $field->list_values( 
			$item->get_value( $field->get_name ) );
	}

	if( $self->{match} eq "EX" )
	{
		# Special handling for exact matches, as it can handle NULL
		# fields.

		foreach( @list )
		{
			if( !EPrints::Utils::is_set( $self->{value} ) )
			{
				return 1 if( !EPrints::Utils::is_set( $_ ) );
			}
			else
			{
				return 1 if( $_ eq $self->{value} );
			}
		}
		return 0;
	}

	if ( $self->is_type( "name" ) )
	{
		my @names = ();
		my $text = $self->{value};

		# Remove spaces before and  after commas. So Jones , C
		# is searched as Jones,C 
		$text =~ s/,\s+/,/g;
		$text =~ s/\s+,/,/g;

		# Extact names in quotes 
		while( $text=~s/"([^"]+)"// ) { push @names, $1; }

		# Extact other names
		while( $text=~s/([^\s]+)// ) { push @names, $1; }

		foreach my $name ( @names )
		{
			$name =~ m/^([^,]+)(,(.*))?$/;
			my( $family, $given ) = ( $1, $3 );
			$family = "" if( !defined $family );
			$given = "" if( !defined $given );

			my $match = 0;
			foreach( @list )
			{
				if( _name_cmp( 
					$family, 
					$given, 
					$self->{match} eq "IN", 
					$_ ) )
				{
					$match = 1;
					last;
				}
			}
			return 1 if( $match && $self->{merge} eq "ANY" );
			return 0 if( !$match && $self->{merge} ne "ANY" );
		}
		if( $self->{merge} eq "ANY" )
		{
			return 0;
		}
		else 
		{
			return 1;
		}
	}


	if( $self->is_type( "set", "subject", "datatype", "boolean" ) )
	{
		my @ids = ();
		my $text = $self->{value};
		while( $text=~s/"([^"]+)"// ) { push @ids, $1; }
		while( $text=~s/([^\s]+)// ) { push @ids, $1; }

		my $haystack = \@list;

		if( $self->is_type( "subject" ) )
		{
			$haystack = [];
			foreach( @list )
			{
				my $s = EPrints::Subject->new( 
					$item->get_session,
					$_ );
				if( !defined $s )
				{
					$item->get_session->get_archive->log(
"Attempt to call item_matches on a searchfield with non-existant\n".
"subject id: $_" );
				}
				else
				{
					push @{$haystack}, 
						@{$s->get_value( "ancestors" )};
				}
			}
		}

		return EPrints::Utils::is_in( 
			\@ids, 
			$haystack,
			$self->{merge} ne "ANY" );
	}

	if( $self->is_type( "year", "int" ) )
	{
		my( $from, $to );
		if( $self->{value} =~ m/^(\d+)$/ )
		{
			# Simple single number
			return EPrints::Utils::is_in( 
				[ $1 ],
				\@list,
				1 );
		}
		unless( $self->{value} =~ m/^(\d+)?\-(\d+)?$/ )
		{
			return 0;
		}
		my( $min, $max ) = ( $1, $2 );
		
		foreach( @list )
		{
			my $ok = 1;
			$ok = 0 unless( defined $_ );
			$ok = 0 if( defined $min && $_ < $min );
			$ok = 0 if( defined $max && $_ > $max );
			return 1 if $ok;
		}
		return 0;
	}		

	if( $self->is_type( "date" ) )
	{
		my( $from, $to );
		if( $self->{value} =~ m/^\d\d\d\d-\d\d-\d\d$/ )
		{
			# Simple single date
			return EPrints::Utils::is_in( 
				[ $self->{value} ],
				\@list,
				1 );
		}
		unless( $self->{value} =~ 
			m/^(\d\d\d\d\-\d\d\-\d\d)?\-(\d\d\d\d\-\d\d\-\d\d)?$/ )
		{
			return 0;
		}
		my( $min, $max ) = ( $1, $2 );
		
		foreach( @list )
		{
			my $ok = 1;
			$ok = 0 unless( defined $_ );
			$ok = 0 if( defined $min && $_ lt $min );
			$ok = 0 if( defined $max && $_ gt $max );
			return 1 if $ok;
		}
		return 0;
	}		

	# text, longtext, url, email:

	if( $self->is_type( "text", "longtext", "email", "url", "id" ) )
	{
		if( $self->{match} eq "EQ" )
		{
			my @ids = ();
			my $text = $self->{value};
			while( $text=~s/([^\s]+)// ) { push @ids, $1; }
			return EPrints::Utils::is_in( 
				\@ids,
				\@list,
				$self->{merge} ne "ANY" );
		}
			
		my( $needles , $bad ) = 
			$self->{session}->get_archive()->call(
				"extract_words",
				$self->{value} );

		my $haystack = [];
		foreach( @list )
		{
			my( $a , $b ) = 
				$self->{session}->get_archive()->call(
					"extract_words",
					$_ );
			push @{$haystack}, @{$a};
		}
		
		return EPrints::Utils::is_in( 
			$needles,
			$haystack,
			$self->{merge} ne "ANY" );

	}

	return 0;
}


sub _name_cmp
{
	my( $family, $given, $in, $name ) = @_;

	my $nfamily = lc $name->{family};
	my $ngiven = substr( lc $name->{given}, 0, length( $given ) );

	if( $in )
	{
		$nfamily = substr( $nfamily, 0, length( $family ) );
	}

	return( 0 ) unless( lc $family eq $nfamily );
	return( 0 ) unless( lc $given eq $ngiven );
	return( 1 );
}
	
1;

######################################################################
=pod

=back

=cut

