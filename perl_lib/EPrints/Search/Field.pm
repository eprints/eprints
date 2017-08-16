######################################################################
#
# EPrints::Search::Field
#
######################################################################
#
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
whitespace separated words, or other search criteria.

A search field has four key parameters:

1. The list of the metadata fields it searches.

2. The value to search for.

3. The "match" parameter which can be one of:

=over 4

=item match=IN

Treat the value as a list of whitespace-separated words. Search for
each one in the full-text index.

In the case of subjects, match these subject ids or the those of any
of their descendants in the subject tree.

=item match=EQ (equal)

Treat the value as a single string. Match only fields which have this
value.

=item match=EX (exact)

If the value is an empty string then search for fields which are
empty, as oppose to skipping this search field.

In the case of subjects, match the specified subjects, but not their
descendants.

=item match=SET

If the value is non-empty.

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
#  $searchfield->{"fields"}
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

=item $sf = EPrints::Search::Field->new( %opts )

	repository
	dataset
	fields - field or fields to search
	value - value to search for
	match
	merge
	prefix
	show_help
	id

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
#	my( $class, $session, $dataset, $fields, $value, $match, $merge, $prefix, $id, $show_help ) = @_;
	my( $class, %self ) = @_;

	my $self = bless \%self, $class;
	
	$self{fields} = [$self{fields}] if ref($self{fields}) ne "ARRAY";
	$self{field} = $self{fields}->[0];

	if( !defined $self{field} || !UNIVERSAL::isa( $self{field}, 'EPrints::MetaField' ) )
	{
		EPrints->abort( "fields must be a MetaField or list of MetaFields" );
	}

	$self{repository} ||= $self{dataset}->repository;

	my $repository = $self{repository};

	# argument or field default or EQ/ALL
	$self{match} = $self{match} ? $self{match} : (defined $self{field} ?
				$self{field}->property( "match" ) : "EQ");
	$self{merge} = $self{merge} ? $self{merge} : (defined $self{field} ?
				$self{field}->property( "merge" ) : "ALL");

	if( $self{match} ne "EQ" && $self{match} ne "IN" && $self{match} ne "EX" && $self{match} ne "SET" )
	{
		$repository->log( 
"search field match value was '".$self{match}."'. Should be EQ, IN or EX." );
		$self{match} = "EQ";
	}

	if( $self{merge} ne "ALL" && $self{merge} ne "ANY" )
	{
		$repository->log( 
"search field merge value was '".$self{merge}."'. Should be ALL or ANY." );
		$self{merge} = "ALL";
	}

	$self{show_help} = "toggle" unless defined $self{show_help};
	if( $self{show_help} ne "toggle" && $self{show_help} ne "always" && $self{show_help} ne "never" )
	{
		$repository->log( 
"search field show_help value was '".$self{show_help}."'. Should be toggle, always or never." );
		$self{show_help} = "toggle";
	}

	my( @fieldnames );
	foreach my $f (@{$self{fields}})
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
	$self{rawid} = join '/', sort @fieldnames;

	$self{id} = $self{rawid} if !defined $self{id};

	my $prefix = $self{prefix};
	$prefix = "" unless defined $prefix;
		
	$self{form_name_prefix} = $prefix.$self{id};

	# a search is "simple" if it contains a mix of fields. 
	# 'text indexable" fields (longtext,text,url & email) all count 
	# as one type. int & year count as one type.

	foreach my $f (@{$self{fields}})
	{
		my $f_searchgroup = $f->get_search_group;
		if( !defined $self{"search_mode"} ) 
		{
			$self{search_mode} = $f_searchgroup;
			next;
		}
		if( $self{search_mode} ne $f_searchgroup )
		{
			$self{search_mode} = 'simple';
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
	delete $self->{value};
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

	my( $value, $match, $merge, $problem) =
		$self->{"field"}->from_search_form( 
			$self->{"repository"}, 
			$self->{"form_name_prefix"} );

	if( EPrints::Utils::is_set( $value ) )
	{
		$self->{value} = $value;
	}
	elsif( EPrints::Utils::is_set( $self->{default} ) )
	{
		$self->{value} = $self->{default};
	}
	$self->{match} = $match if $match && $match =~ /^EQ|IN|EX|SET$/;
	$self->{merge} = $merge if $merge && $merge =~ /^ANY|ALL$/;

	# match = NO? if value==""

	if( $problem )
	{
		$self->{"match"} = "NO";
	}

	return $problem;
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

	if( $self->{"match"} eq "SET" )
	{
		return $self->get_conditions_no_split( $self->{"value"} );
	}

	if( !EPrints::Utils::is_set( $self->{"value"} ) )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	if( $self->{"search_mode"} eq "simple" )
	{
		return $self->get_conditions_simple( $self->{value} );
	}

	my @parts = $self->{"field"}->split_search_value( 
			$self->{"repository"},
			$self->{"value"} );

	my @r = ();
	foreach my $value ( @parts )
	{
		my $cond = $self->get_conditions_no_split( $value );
		push @r, $cond if !$cond->is_empty;
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
	foreach my $field ( @{$self->{"fields"}} )
	{
		my $cond = $field->get_search_conditions( 
				$self->{"repository"},
				$self->{"dataset"},
				$search_value,
				$self->{"match"},
				$self->{"merge"},
				$self->{"search_mode"} );
		push @r, $cond if !$cond->is_empty();
	}

	return EPrints::Search::Condition->new( 'OR', @r );
}	

# get conditions for a simple search
#  - split out field-specific queries e.g. title:(amazonian turtles)
#  - split remaining terms and apply a MERGE of each term ORed across all
#  fields
#  - join all the queries together according to the current MERGE
sub get_conditions_simple
{
	my( $self, $q ) = @_;

	# generate a regexp to match aliased search terms
	my %aliases;
	foreach my $field ( @{$self->{"fields"}} )
	{
		$aliases{$field->name} = $field;
	}
	my $alias = join '|', map { "(?:$_)" } keys %aliases;
	$alias = qr/$alias/i;

	my @r = ();

	# pull out field-specific values
	my %values;
	while( $q =~ s/($alias):((?:"[^"]+")|(?:\([^\)]+\))|\S+)// )
	{
		push @{$values{lc($1)}}, $2;
	}

	foreach my $name (keys %values)
	{
		my $field = $aliases{$name};
		foreach my $value (@{$values{$name}})
		{
			my @inner;
			foreach my $v ($field->split_search_value( $self->{repository}, $value ))
			{
				my $cond = $field->get_search_conditions( 
							$self->{"repository"},
							$self->{"dataset"},
							$v,
							$field->property( "match" ),
							$field->property( "merge" ),
							"advanced" # equivalent to advanced search
							);
				push @inner, $cond if !$cond->is_empty();
			}
			next if !@inner;
			if( $field->property( "merge" ) eq "ALL" )
			{
				push @r, EPrints::Search::Condition->new( 'AND', @inner );
			}
			else
			{
				push @r, EPrints::Search::Condition->new( 'OR', @inner );
			}
		}
	}

	my @values = $self->split_value( $q );
	
	foreach my $value (@values)
	{
		my @inner;
		foreach my $field (@{$self->{fields}})
		{
			next if $values{$field->name}; # already searching

			my $cond = $field->get_search_conditions( 
					$self->{"repository"},
					$self->{"dataset"},
					$value,
					$self->{"match"},
					$self->{"merge"},
					$self->{"search_mode"} );
			push @inner, $cond if !$cond->is_empty();
		}
		next if !@inner;
		if( $self->{merge} eq "ALL" )
		{
			push @r, EPrints::Search::Condition->new( 'OR', @inner );
		}
		else
		{
			push @r, @inner;
		}
	}

	return EPrints::Search::Condition->new( $self->{merge} eq "ANY" ? "OR" : "AND", @r );
}

sub split_value
{
	my( $self, $value ) = @_;

	my @values = EPrints::Index::Tokenizer::split_search_value( 
		$self->{"repository"},
		$value );
	# unless we strip stop-words 'the' will get passed through to name
	# matches causing no results (doesn't help in the search description)
	my $freetext_stop_words = $self->{repository}->config(
			"indexing",
			"freetext_stop_words"
		);
	my $freetext_always_words = $self->{repository}->config(
			"indexing",
			"freetext_always_words"
		);
	@values = grep {
			EPrints::Utils::is_set( $_ ) &&
			($freetext_always_words->{lc($_)} ||
			!$freetext_stop_words->{lc($_)})
		} @values;

	return @values;
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
	return $self->{"fields"};
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
	my( $self, %opts ) = @_;

	return $self->{"field"}->render_search_input( $self->{"repository"}, $self, %opts );
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

	my $frag = $self->{"repository"}->make_doc_fragment;

	my $sfname = $self->render_name;

	return $self->{"field"}->render_search_description(
			$self->{"repository"},
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
		if( $self->{"repository"}->get_lang->has_phrase( $phraseid, $self->{"repository"} ) )
		{
			return $self->{"repository"}->html_phrase( $phraseid );
		}
	}

	# No id was set, gotta make a normal name from 
	# the metadata fields.
	my( $sfname ) = $self->{"repository"}->make_doc_fragment;
	my( $first ) = 1;
	foreach my $f (@{$self->{"fields"}})
	{
		if( !$first ) 
		{ 
			$sfname->appendChild( 
				$self->{"repository"}->make_text( "/" ) );
		}
		$first = 0;
		$sfname->appendChild( $f->render_name( $self->{"repository"} ) );
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
	if( $self->{"repository"}->get_lang->has_phrase( $custom_help, $self->{"repository"} ) )
	{
		$phrase_id = $custom_help;
	}
		
	return $self->{"repository"}->html_phrase( $phrase_id );
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

	return 1 if $self->{"match"} eq "SET";

	return 0 if !exists( $self->{value} );

	return
		EPrints::Utils::is_set( $self->{"value"} ) ||
		($self->{"match"} eq "EX" && $self->{"merge"} eq "ALL") ||
		$self->{"match"} eq "SET";
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
		my $item = defined $_ ? $_ : "";
		push @escapedparts, URI::Escape::uri_escape( $item, ':' );
	}
	return join( ":" , @escapedparts );
}

######################################################################
=pod

=item $sf = EPrints::Search::Field->unserialise( %opts )

	repository
	dataset
	string

Convert a serialised searchfield back into a search field.

=cut
######################################################################

sub unserialise
{
	my( $class, %opts ) = @_;

	my $string = delete $opts{string};

	my $data = {};
	@{$data}{qw( id rawid merge match value )} = split ':', $string, 5;
	return if !defined $data->{value};
	$data->{value} = URI::Escape::uri_unescape( $data->{value} );

	my @fields;
	foreach my $fname ( split( "/", $data->{rawid} ) )
	{
		push @fields,
			EPrints::Utils::field_from_config_string( $opts{dataset}, $fname );
		return if !defined $fields[$#fields];
	}
	return if !@fields;

	return $class->new(
		%$data,
		fields => \@fields,
		%opts,
	);
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




=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

