######################################################################
#
# EPrints::Search::Field
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

B<EPrints::Search::Field> - One field in a search expression.

=head1 DESCRIPTION

This class represents a single field in a search expression, and by
extension a search form.

It should not be confused with MetaField.

It can search over several metadata fields, and the value of the
value of the search field is usually a string containing a list of
whitespace seperated words, or other search criteria.

A search field has four key parameters:

1. The list of the metadata fields it searches.

2. The value to search for.

3. The "match" parameter which can be one of:

=over 4

=item match=IN

Treat the value as a list of whitespace-seperated words. Search for
each one in the full-text index.

In the case of subjects, match these subject ids or the those of any
of their decendants in the subject tree.

=item match=EQ (equal)

Treat the value as a single string. Match only fields which have this
value.

=item match=EX (exact)

If the value is an empty string then search for fields which are
empty, as oppose to skipping this search field.

In the case of subjects, match the specified subjects, but not their
decendants.

=item match=NO

This is only really used internally, it means the search field will
just fail to match anything without doing any actual searching.

=back

4. the "merge" parameter which can be one of:

=over 4

=item merge=ANY 

Match an item if any of the words in the value match.

=item merge=ALL 

Match an item only if all of the words in the value match.

=back



=head2 METHODS

=over 4

=cut

######################################################################
#
# INSTANCE VARIABLES:
#
#  $searchfield->{"session"}
#     The current EPrints::Session
#
#  $searchfield->{"dataset"}
#     The EPrints::DataSet which this search field will search
#
#  $searchfield->{"match"}
#     see above.
#
#  $searchfield->{"merge"}
#     see above.
#
#  $searchfield->{"value"}
#     see above.
#
#  $searchfield->{"fieldlist"}
#     The list of EPrints::MetaField to search.
#
#  $searchfield->{"field"}
#     A single field which is used to render the search form for
#     that kind of field. 
#
#  $searchfield->{"form_name_prefix"}
#     The prefix to use in the HTML form.
#
#  $searchfield->{"search_mode"}
#     If all the fields are similar then this is their search group
#     rough groups are dates, strings, integers, names and sets. If
#     fields from more than one group are being searched at once then
#     a search syntax specific to that group can't be used and the
#     search_mode is set to "simple".
#
######################################################################


package EPrints::Search::Field;

use strict;

# Nb. match=EX searches CANNOT be used in the HTML form (currently)
# EX is "Exact", like EQuals but allows blanks.
# EX search on subject only searches for that subject, not things
# below it.

######################################################################
=pod

=item $thing = EPrints::Search::Field->new( $session, $dataset, $fields, $value, [$match], [$merge], [$prefix], [$show_help] )

Create a new search field object. 

$prefix is used when generating HTML forms and reading values from forms. 

$fields is a reference to an array of field names.

$match is one of EQ, IN, EX. default is EQ.

$merge is ANY or ALL. default is ALL

Special case - if match is "EX" and field type is name then value must
be a name hash.

$show_help is used to control if the help shows up on the search form. A value of "always" shows the help without the show/hide toggle. "never" shows no help and no toggle. "toggle" shows no help, but shows the [?] icon which will reveal the help. The default is "toggle". If javascript is off, toggle will show the help and show no toggle.

=cut
######################################################################

sub new
{
	my( $class, $session, $dataset, $fields, $value, $match, $merge, $prefix, $id, $show_help ) = @_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{"session"} = $session;
	$self->{"dataset"} = $dataset;

	$self->{"value"} = $value;
	$self->{"match"} = "EQ";
	$self->{"match"} = $match if( EPrints::Utils::is_set( $match ) );
	$self->{"merge"} = "ALL";
	$self->{"merge"} = $merge if( EPrints::Utils::is_set( $merge ) );
	if( $self->{match} ne "EQ" && $self->{match} ne "IN" && $self->{match} ne "EX" )
	{
		$session->get_repository->log( 
"search field match value was '".$self->{match}."'. Should be EQ, IN or EX." );
		$self->{merge} = "ALL";
	}

	if( $self->{merge} ne "ALL" && $self->{merge} ne "ANY" )
	{
		$session->get_repository->log( 
"search field merge value was '".$self->{merge}."'. Should be ALL or ANY." );
		$self->{merge} = "ALL";
	}

	$self->{"show_help"} = $show_help;
	$self->{"show_help"} = "toggle" unless defined $self->{"show_help"};
	if( $self->{"show_help"} ne "toggle" && $self->{"show_help"} ne "always" && $self->{"show_help"} ne "never" )
	{
		$session->get_repository->log( 
"search field show_help value was '".$self->{"show_help"}."'. Should be toggle, always or never." );
		$self->{"show_help"} = "toggle";
	}

	if( ref( $fields ) ne "ARRAY" )
	{
		$fields = [ $fields ];
	}

	$self->{"fieldlist"} = $fields;

	$prefix = "" unless defined $prefix;
		
	my( @fieldnames );
	foreach my $f (@{$self->{"fieldlist"}})
	{
		if( !defined $f ) { EPrints::abort( "field not defined" ); }
		my $jp = $f->get_property( "join_path" );
		if( defined $jp )
		{
			my @join_bits = ();
			foreach my $join ( @{$jp} )
			{
				my( $j_field, $j_dataset ) = @{$join};
				push @join_bits, $j_field->get_sql_name();
			}
			push @join_bits, $f->get_sql_name;
			push @fieldnames, join( ".", @join_bits );
			next;
		}

		push @fieldnames, $f->get_sql_name();
	}
	$self->{rawid} = join '/', sort @fieldnames;

	$self->{"id"} = $id || $self->{rawid};

	$self->{"form_name_prefix"} = $prefix.$self->{"id"};
	$self->{"field"} = $fields->[0];

	# a search is "simple" if it contains a mix of fields. 
	# 'text indexable" fields (longtext,text,url & email) all count 
	# as one type. int & year count as one type.

	foreach my $f (@{$fields})
	{
		my $f_searchgroup = $f->get_search_group;
		if( !defined $self->{"search_mode"} ) 
		{
			$self->{"search_mode"} = $f_searchgroup;
			next;
		}
		if( $self->{"search_mode"} ne $f_searchgroup )
		{
			$self->{"search_mode"} = 'simple';
			last;
		}
	}

	return $self;
}

	

######################################################################
=pod

=item $sf->clear

Set this searchfield's "match" to "NO" so that it always returns
nothing when searched.

=cut
######################################################################

sub clear
{
	my( $self ) = @_;
	
	$self->{"match"} = "NO";
	$self->{"value"} = undef;
}



######################################################################
=pod

=item $problem = $sf->from_form

Modify the value, merge and match parameters of this field based on
results from an HTML form.

Return undef if everything is OK, otherwise return a ref to an array
containing the problems as XHTML DOM objects.

=cut
######################################################################

sub from_form
{
	my( $self ) = @_;

	my $problem;

	( $self->{"value"}, $self->{"merge"}, $self->{"match"}, $problem ) =
		$self->{"field"}->from_search_form( 
			$self->{"session"}, 
			$self->{"form_name_prefix"} );

	$self->{"value"} = "" unless( defined $self->{"value"} );
	$self->{"merge"} = "ALL" unless( defined $self->{"merge"} );
	$self->{"match"} = "EQ" unless( defined $self->{"match"} );

	# match = NO? if value==""

	if( $problem )
	{
		$self->{"match"} = "NO";
		return $problem;
	}

	return;
}
	
	



######################################################################
=pod

=item $search_condition = $sf->get_conditions 

Convert this Search::Field into an EPrints::Search::Condition object which
can actually perform the search.

=cut
######################################################################

sub get_conditions
{
	my( $self ) = @_;

	if( $self->{"match"} eq "NO" )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	if( $self->{"match"} eq "EX" )
	{
		return $self->get_conditions_no_split( $self->{"value"} );
	}

	if( !EPrints::Utils::is_set( $self->{"value"} ) )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	my @parts;
	if( $self->{"search_mode"} eq "simple" )
	{
		@parts = EPrints::Index::split_words( 
			$self->{"session"},  # could be just archive?
			EPrints::Index::apply_mapping( 
				$self->{"session"}, 
				$self->{"value"} ) );
	}
	else
	{
		@parts = $self->{"field"}->split_search_value( 
			$self->{"session"},
			$self->{"value"} );
	}

	my @r = ();
	foreach my $value ( @parts )
	{
		push @r, $self->get_conditions_no_split( $value );
	}
	
	return EPrints::Search::Condition->new( 
		($self->{"merge"}eq"ANY"?"OR":"AND"), 
		@r );
}

# Internal function for get_conditions

sub get_conditions_no_split
{
	my( $self,  $search_value ) = @_;

	# special case for name?

	my @r = ();
	foreach my $field ( @{$self->{"fieldlist"}} )
	{
		push @r, $field->get_search_conditions( 
				$self->{"session"},
				$self->{"dataset"},
				$search_value,
				$self->{"match"},
				$self->{"merge"},
				$self->{"search_mode"} );
	}
	return EPrints::Search::Condition->new( 'OR', @r );
}	


	
######################################################################
=pod

=item $value = $sf->get_value

Return the current value parameter of this search field.

=cut
######################################################################

sub get_value
{
	my( $self ) = @_;

	return $self->{"value"};
}


######################################################################
=pod

=item $match = $sf->get_match

Return the current match parameter of this search field.

=cut
######################################################################

sub get_match
{
	my( $self ) = @_;

	return $self->{"match"};
}


######################################################################
=pod

=item $merge = $sf->get_merge

Return the current merge parameter of this search field.

=cut
######################################################################

sub get_merge
{
	my( $self ) = @_;

	return $self->{"merge"};
}



######################################################################
=pod

=item $field = $sf->get_field

Return the first of the metafields which we are searching. This is
used for establishing the type of the search field. If this metafield
has special input rendering methods then they will be used for this
search field.

=cut
######################################################################

sub get_field
{
	my( $self ) = @_;
	return $self->{"field"};
}

######################################################################
=pod

=item $fields = $sf->get_fields

Return a reference to an array of EPrints::MetaField objects which 
this search field is going to search.

=cut
######################################################################

sub get_fields
{
	my( $self ) = @_;
	return $self->{"fieldlist"};
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
	my( $self ) = @_;

	return $self->{"field"}->render_search_input( $self->{"session"}, $self );
}

######################################################################
=pod

=item $xhtml = $sf->get_form_prefix

Return the string use to prefix form field names so values
don't get mixed with other search fields.

=cut
######################################################################

sub get_form_prefix
{
	my( $self ) = @_;
	return $self->{"form_name_prefix"};
}



######################################################################
=pod

=item $xhtml = $sf->render_description

Returns an XHTML DOM object describing this field and its current
settings. Used at the top of the search results page to describe
the search.

=cut
######################################################################

sub render_description
{
	my( $self ) = @_;

	my $frag = $self->{"session"}->make_doc_fragment;

	my $sfname = $self->render_name;

	return $self->{"field"}->render_search_description(
			$self->{"session"},
			$sfname,
			$self->{"value"},
			$self->{"merge"},
			$self->{"match"} );
}

######################################################################
=pod

=item $xhtml_name = $sf->render_name

Return XHTML object of this searchfields name.

=cut
######################################################################

sub render_name
{
	my( $self ) = @_;

	if( defined $self->{"id"} )
	{
		my $phraseid = "searchfield_name_".$self->{"id"};
		if( $self->{"session"}->get_lang->has_phrase( $phraseid, $self->{"session"} ) )
		{
			return $self->{"session"}->html_phrase( $phraseid );
		}
	}

	# No id was set, gotta make a normal name from 
	# the metadata fields.
	my( $sfname ) = $self->{"session"}->make_doc_fragment;
	my( $first ) = 1;
	foreach my $f (@{$self->{"fieldlist"}})
	{
		if( !$first ) 
		{ 
			$sfname->appendChild( 
				$self->{"session"}->make_text( "/" ) );
		}
		$first = 0;
		$sfname->appendChild( $f->render_name( $self->{"session"} ) );
	}
	return $sfname;
}


######################################################################
=pod

=item $xhtml_help = $sf->render_help

Return an XHTML DOM object containing the "help" for this search
field.

=cut
######################################################################

sub render_help
{
	my( $self ) = @_;

	my $custom_help = "searchfield_help_".$self->{"id"};
	my $phrase_id = "lib/searchfield:help_".$self->{"field"}->get_type();
	if( $self->{"session"}->get_lang->has_phrase( $custom_help, $self->{"session"} ) )
	{
		$phrase_id = $custom_help;
	}
		
	return $self->{"session"}->html_phrase( $phrase_id );
}


######################################################################
=pod

=item $boolean = $sf->is_type( @types )

Return true if the first metafield in the fieldlist is of any of the
types in @types.

=cut
######################################################################

sub is_type
{
	my( $self, @types ) = @_;
	return $self->{"field"}->is_type( @types );
}


######################################################################
=pod

=item $id = $sf->get_id

Return the string ID of this searchfield. It is the "id" specified
when the string was configured, or failing that the names of all the
metafields it searches, joined with a slash "/".

=cut
######################################################################

sub get_id
{
	my( $self ) = @_;
	return $self->{"id"};
}


######################################################################
=pod

=item $boolean = $sf->is_set

Returns true if this search field has a value to search.

If the "match" parameter is set to "EX" then it always returns true,
even if the value is "" because "" is a valid search value in
"EX" searches.

=cut
######################################################################

sub is_set
{
	my( $self ) = @_;

	return EPrints::Utils::is_set( $self->{"value"} ) || $self->{"match"} eq "EX";
}


######################################################################
=pod

=item $string = $sf->serialise

Serialise the parameters of this search field into a string.

=cut
######################################################################

sub serialise
{
	my( $self ) = @_;

	return undef unless( $self->is_set() );

	my @escapedparts;
	foreach($self->{"id"},
		$self->{"rawid"}, 	
		$self->{"merge"}, 	
		$self->{"match"}, 
		$self->{"value"} )
	{
		my $item = $_;
		$item =~ s/[\\\:]/\\$&/g;
		push @escapedparts, $item;
	}
	return join( ":" , @escapedparts );
}



######################################################################
=pod

=item $params = EPrints::Search::Field->unserialise( $string )

Convert a serialised searchfield into a hash reference containing the 
params: id, merge, match, value.

Does not return a EPrints::Search::Field object.

=cut
######################################################################

sub unserialise
{
	my( $class, $string ) = @_;

	$string=~m/^([^:]*):([^:]*):([^:]*):(.*):(.*)$/;
	my $data = {};
	$data->{"id"} = $1;
	$data->{"rawid"} = $2;
	$data->{"merge"} = $3;
	$data->{"match"} = $4;
	$data->{"value"} = $5;
	# Un-escape (cjg, not very tested)
	$data->{"value"} =~ s/\\(.)/$1/g;

	return $data;
}

######################################################################
=pod

=item $boolean  = $sf->get_include_in_description

Change the dataset of this searchfield. This is probably a bad idea,
except moving between two datasets with the same confid. eg. buffer
and inbox.

=cut
######################################################################

sub get_include_in_description
{
	my( $self ) = @_;

	my $r = $self->{"include_in_description"};

	return $r if defined $r;

	return 1;
}

######################################################################
=pod

=item $sf->set_include_in_description( $boolean )

If set to zero then this search field will not be included in 
descriptions of the search.

=cut
######################################################################

sub set_include_in_description
{
	my( $self, $boolean ) = @_;

	$self->{"include_in_description"} = 1;
	if( defined $boolean && $boolean == 0 ) { $self->{"include_in_description"} = 0; }
}


######################################################################
=pod

=item $sf->set_dataset( $datasetid )

Change the dataset of this searchfield. This is probably a bad idea,
except moving between two datasets with the same confid. eg. buffer
and inbox.

=cut
######################################################################

sub set_dataset
{
	my( $self, $dataset ) = @_;

	$self->{"dataset"} = $dataset;
}




1;

######################################################################
=pod

=back

=cut



