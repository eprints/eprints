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

=pod

=head1 NAME

EPrints::MetaField - Class representing an information field in an eprint dataset

=head1 SYNOPSIS

 use EPrints::Metafield;

 my $field = EPrints::Metafield->new(
	dataset => $session->get_archive()->get_dataset( "archive" ),
	name => "authors",
	type => "name",
	multiple => 1 );
	
 my $dom_fragment = $field->render_value( $session, $value );


=cut 

# Bugs: Need to be able to unset 'sets' which are no multiple and
# not required.


package EPrints::MetaField;

use EPrints::Utils;
use EPrints::Session;
use EPrints::Subject;
use EPrints::Database;

use strict;
#CJG Option for Boolean to be a menu or radio buttons?

# Months
my @monthkeys = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );


# list of legal properties used to check
# get & set property.

# a setting of -1 means that this property must be set
# explicitly and does not therefore have a default

my $PROPERTIES = 
{
	datasetid => -1,
	digits => 1,
	input_rows => 1,
	input_cols => 1,
	input_name_cols => 1,
	input_id_cols => 1,
	input_add_boxes => 1,
	input_boxes => 1,
	input_style => 1,
	fromform => 1,
	toform => 1,
	maxlength => 1,
	hasid => 1,
	multilang => 1,
	multiple => 1,
	name => -1,
	options => -1,
	required => 1,
	requiredlangs => 1,
	showall => 1,
	showtop => 1,
	idpart => 1,
	mainpart => 1,
	render_single_value => 1,
	render_value => 1,
	top => 1,
	type => -1
};

######################################################################
#
##
# cjg comment?
######################################################################
# name   **required**
# type   **required**
# required # default = no
# multiple # default = no
# 
# input_rows   # for longtext and set (int)   # default = 5
# digits  # for int  (int)   # default = 20
# options # for set (array)   **required if type**
# maxlength # for text (maybe url & email?)
# showtop, showall # for subjects

# hasid # for all - has an ID value(s)
# idpart, mainpart # internal use only by the "ID" fields sub-fields.

# note: display name, help and labels for options are not
# defined here as they are lang specific.

## WP1: BAD
sub new
{
	my( $class, %properties ) = @_;
	
	my $self = {};
	bless $self, $class;

	$self->{confid} = $properties{confid};

	if( defined $properties{dataset} ) { 
		$self->{confid} = $properties{dataset}->confid(); 
		$self->{dataset} = $properties{dataset};
	}
	$self->set_property( "name", $properties{name} );
	$self->set_property( "type", $properties{type} );
	if( $self->is_type( "datatype" ) )
	{
		$self->set_property( "datasetid" , $properties{datasetid} );
	}

	if( $self->is_type( "set" ) )
	{
		$self->set_property( "options" , $properties{options} );
	}
	my $p;
	foreach $p ( keys %{$PROPERTIES} )
	{
		next unless( $PROPERTIES->{$p} == 1 );
		$self->set_property( $p, $properties{$p} );
	}

	return( $self );
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

	return EPrints::MetaField->new( %{$self} );
}



#
# ( $year, $month, $day ) = get_date( $time )
#
#  Static method that returns the given time (in UNIX time, seconds 
#  since 1.1.79) in the format used by EPrints and MySQL (YYYY-MM-DD).
#

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

sub tags_and_labels
{
	my( $self , $session ) = @_;
	my %labels = ();
	foreach( @{$self->{options}} )
	{
		$labels{$_} = $self->display_option( $session, $_ );
	}
	return ($self->{options}, \%labels);
}

sub display_name
{
	my( $self, $session ) = @_;

	my $phrasename = $self->{confid}."_fieldname_".$self->{name};
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );

	return $session->phrase( $phrasename );
}

sub display_help
{
	my( $self, $session ) = @_;

	my $phrasename = $self->{confid}."_fieldhelp_".$self->{name};
	$phrasename.= "_id" if( $self->get_property( "idpart" ) );

	return $session->phrase( $phrasename );
}

sub display_option
{
	my( $self, $session, $option ) = @_;

	my $phrasename = $self->{confid}."_fieldopt_".$self->{name}."_".$option;

	return $session->phrase( $phrasename );
}

sub get_sql_type
{
        my( $self , $notnull ) = @_;

	my $sqlname = $self->get_sql_name();
	my $param = "";
	$param = "NOT NULL" if( $notnull );

	if( $self->is_type( "int", "year" ) )
	{
 		return $sqlname.' INTEGER '.$param;
	}

	if( $self->is_type( "langid" ) )
	{
 		return $sqlname.' CHAR(16) '.$param;
	}

	if( $self->is_type( "longtext" ) )
	{
 		return $sqlname.' TEXT '.$param;
	}

	if( $self->is_type( "date" ) )
	{
 		return $sqlname.' DATE '.$param;
	}

	if( $self->is_type( "boolean" ) )
	{
 		return $sqlname." SET('TRUE','FALSE') ".$param;
	}

	my $varchar_size = $self->get_dataset()->get_archive()->get_conf( "varchar_size" );

	if( $self->is_type( "name" ) )
	{
		return $sqlname."_honourific VARCHAR($varchar_size) ".$param.", ".
			$sqlname."_given VARCHAR($varchar_size) ".$param.", ".
			$sqlname."_family VARCHAR($varchar_size) ".$param.", ".
			$sqlname."_lineage VARCHAR($varchar_size) ".$param;
	}

	# all others: set, text, secret, url, email, subject, pagerange, datatype, id

	# This is not very effecient, but diskspace is cheap, right?

	return $sqlname." VARCHAR($varchar_size) ".$param;
}

sub get_sql_index
{
        my( $self ) = @_;

	if( $self->is_type( "longtext", "secret" ) )
	{
		return undef;
	}

	my $sqlname = $self->get_sql_name();
	
	if( $self->is_type( "name" ) )
	{
		return "INDEX( ".$sqlname."_given), INDEX( ".$sqlname."_family)";
	}

	return "INDEX( ".$sqlname.")";
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

sub set_property
{
	my( $self , $property , $value ) = @_;

	if( !defined $PROPERTIES->{$property} )
	{
		die "BAD METAFIELD set_property NAME: \"$property\"";
	}
	if( !defined $value )
	{
		if( $PROPERTIES->{$property} == -1 )
		{
			EPrints::Config::abort( $property." on a metafield can't be undef" );
		}
		$self->{$property} = $self->get_property_default( $property );
	}
	else
	{
		$self->{$property} = $value;
	}
}

sub get_property
{
	my( $self, $property ) = @_;

	if( !defined $PROPERTIES->{$property})
	{
		die "BAD METAFIELD get_property NAME: \"$property\"";
	}

	return( $self->{$property} ); 
} 

sub is_type
{
	my( $self , @typenames ) = @_;

	foreach( @typenames )
	{
		return 1 if( $self->{type} eq $_ );
	}
	return 0;
}

sub is_text_indexable
{
	my( $self ) = @_;
	return $self->is_type( "text","longtext","url","email" );
}


sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	if( defined $self->{render_value} )
	{
		return &{$self->{render_value}}( $session, $self, $value, $alllangs, $nolink );
	}

	if( !$self->get_property( "multiple" ) )
	{
		return $self->_render_value1( $session, $value, $alllangs, $nolink );
	}

	if(! EPrints::Utils::is_set( $value ) )
	{
		# maybe should just return nothing
		return $session->html_phrase( "lib/metafield:unspecified" );
	}

	my @rendered_values = ();

	my $first = 1;
	my $html = $session->make_doc_fragment();
	
	foreach( @$value )
	{
		if( $first )
		{
			$first = 0;	
		}	
		elsif( $self->is_type( "name" ) )
		{
			#cjg LANG ME BABY
			$html->appendChild( $session->make_text( " and " ) );
		}
		elsif( $self->is_type( "subject" ) )
		{
			; # do nothing
		}
		else
		{
			$html->appendChild( $session->make_text( ", " ) );
		}
		$html->appendChild( $self->_render_value1( $session, $_, $alllangs, $nolink ) );
	}
	return $html;

}


sub _render_value1
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	my $rendered = $self->_render_value2( $session, $value, $alllangs, $nolink );

	if( $self->get_property( "hasid" ) )
	{
		# Ask the usercode to fiddle with this bit of HTML
		# based on the value of it's ID. 
		# It will either just pass it through, redo it from scratch
		# or wrap it in a link.
		
		return $session->get_archive()->call( "render_value_with_id",  
			$self, $session, $value, $alllangs, $rendered, $nolink );
	}
	else
	{
#print STDERR "(".$self->get_name().")(".$self->{browse}.")(".$nolink.")\n";
#cjg fix links to views!
		if( $self->{browse} && !$nolink)
		{
			my $url = $session->get_archive()->get_conf( "base_url" ).
					"/view/".$self->get_name()."/".$value.".html";
			my $a = $session->make_element( "a", href=>$url );
			$a->appendChild( $rendered );
			return $a;
		}
		else
		{
			return $rendered;
		}
	}

}

sub _render_value2
{
	my( $self, $session, $value, $alllangs, $nolink ) = @_;

	# We don't care about the ID
	if( $self->get_property( "hasid" ) )
	{
		$value = $value->{main};
	}

	if( !$self->get_property( "multilang" ) )
	{
		return $self->_render_value3( $session, $value, $nolink );
	}

	if( !$alllangs )
	{
		my $v = EPrints::Session::best_language( $session->get_archive(), $session->get_langid(), %$value );
		return $self->_render_value3( $session, $v, $nolink );
	}
	my( $table, $tr, $td, $th );
	$table = $session->make_element( "table" );
	foreach( keys %$value )
	{
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		$td = $session->make_element( "td" );
		$tr->appendChild( $td );
		$td->appendChild( 
			$self->_render_value3( $session, $value->{$_} ) );
		$th = $session->make_element( "th" );
		$tr->appendChild( $th );
		$th->appendChild( $session->make_text(
			"(".EPrints::Config::lang_title( $_ ).")" ) );
	}
	return $table;
}

sub _render_value3
{
	my( $self, $session, $value, $nolink ) = @_;

	if( !defined $value )
	{
		return $session->html_phrase( "lib/metafield:unspecified" );
	}

	if( defined $self->{render_single_value} )
	{
		return &{$self->{render_single_value}}( $session, $self, $value );
	}

	if( $self->is_type( "text" , "int" , "pagerange" , "year" ) )
	{
		# Render text
		return $session->make_text( $value );
	}

	if( $self->is_type( "secret" ) )
	{
		# cjg better return than ???? ?
		return $session->make_text( "????" );
	}

	if( $self->is_type( "url" ) )
	{
		my $a = $session->make_element( "a", href=>$value );
		$a->appendChild( $session->make_text( $value ) );
		return $a;
	}

	if( $self->is_type( "email" ) )
	{
		my $text =  $session->make_text( $value ) ;
		if( $nolink )
		{
			return $text;
		}
		my $a = $session->make_element( "a", href=>"mailto:".$value );
		$a->appendChild( $text );
		return $a;
	}

	if( $self->is_type( "name" ) )
	{
		return $session->make_text(
			EPrints::Utils::format_name( $session,  $value ) );
	}

	if( $self->is_type( "date" ) )
	{
		return $session->make_text(
			EPrints::Utils::format_date( $session, $value ) );
	}


	if( $self->is_type( "longtext" ) )
	{
		my @paras = split( /\r\n|\r|\n/ , $value );
		my $frag = $session->make_doc_fragment();
		my $first = 1;
		foreach( @paras )
		{
			unless( $first )
			{
				$frag->appendChild( $session->make_element( "br" ) );
			}
			$frag->appendChild( $session->make_text( $_ ) );
			$first = 0;
		}
		return $frag;
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( $self->get_property( "datasetid" ) );
		return $ds->render_type_name( $session, $value ); 
	}

	if( $self->is_type( "set" ) )
	{
		return $session->make_text( 
			$self->display_option( $session , $value ) );
	}

	if( $self->is_type( "boolean" ) )
	{
		return $session->html_phrase( "lib/metafield:".($value eq "TRUE"?"true":"false") );
	}

	
	if( $self->is_type( "subject" ) )
	{
		my $subject = new EPrints::Subject( $session, $value );
		if( !defined $subject )
		{
			return $session->make_text( "?? $value ??" );
		}
		return $subject->render_with_path( $session, $self->get_property( "top" ) );
	}
	
	$session->get_archive()->log( "Unknown field type: ".$self->{type} );
	return $session->make_text( "?? $value ??" );
}


sub render_input_field
{
	my( $self, $session, $value ) = @_;

	if( defined $self->{toform} )
	{
		$value = &{$self->{toform}}( $value, $session );
	}

	my( $html, $frag );

	$html = $session->make_doc_fragment();

	# subject fields can be rendered here and now
	# without looping and calling the aux function.

	if( $self->is_type( "subject", "datatype", "set" ) )
	{
		my %settings;
		$settings{name} = $self->{name};
		$settings{multiple} = 
			( $self->{multiple} ?  "multiple" : undef );

		if( !defined $value )
		{
			$settings{default} = []; 
		}
		elsif( !$self->get_property( "multiple" ) )
		{
			$settings{default} = [ $value ]; 
		}
		else
		{
			$settings{default} = $value; 
		}

		$settings{height} = $self->{input_rows};
		if( $settings{height} ne "ALL" && $settings{height} == 0 )
		{
			$settings{height} = undef;
		}

		if( $self->is_type( "subject" ) )
		{
			my $topsubj = EPrints::Subject->new(
				$session,
				$self->get_property( "top" ) );
			my ( $pairs ) = $topsubj->get_subjects( 
				!($self->{showall}), 
				$self->{showtop} );
			$settings{pairs} = $pairs;
		} else {
			my($tags,$labels);
			if( $self->is_type( "set" ) )
			{
				$tags = $self->{options};
				$labels = {};
				foreach( @{$tags} ) { 
					$labels->{$_} = $self->display_option( $session, $_ );
				}
			}
			else # is "datatype"
			{
				my $ds = $session->get_archive()->get_dataset( 
						$self->{datasetid} );	
				$tags = $ds->get_types();
				$labels = $ds->get_type_names( $session );
			}
			$settings{values} = $tags;
			$settings{labels} = $labels;

		}
		$html->appendChild( $session->render_option_list( %settings ) );

		return $html;
	}

	# The other types require a loop if they are multiple.

	if( $self->get_property( "multiple" ) )
	{
		my $boxcount = $self->{input_boxes};
		my $spacesid = $self->{name}."_spaces";

		if( $session->internal_button_pressed() )
		{
			$boxcount = $session->param( $spacesid );
			if( $session->internal_button_pressed( $self->{name}."_morespaces" ) )
			{
				$boxcount += $self->{input_add_boxes};
			}
		}
	
		my $i;
		for( $i=1 ; $i<=$boxcount ; ++$i )
		{
			my $div;
			$div = $session->make_element( "div" );
			$div->appendChild( $session->make_text( $i.". " ) );
			$html->appendChild( $div );
			$div = $session->make_element( "div", style=>"margin-left: 20px" ); #cjg NOT CSS
			$div->appendChild( 
				$self->_render_input_field_aux( 
					$session, 
					$value->[$i-1], 
					$i ) );
			$html->appendChild( $div );
		}
		$html->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $spacesid,
			value => $boxcount ) );
		$html->appendChild( $session->render_internal_buttons(
			$self->{name}."_morespaces" => 
				$session->phrase( "lib/metafield:more_spaces" ) ) );
	}
	else
	{
		$html->appendChild( 
			$self->_render_input_field_aux( 
				$session, 
				$value ) );
	}

	return $html;
}

sub _render_input_field_aux
{
	my( $self, $session, $value, $n ) = @_;

	my $suffix = (defined $n ? "_$n" : "" );	

	my $idvalue;
	if( $self->get_property( "hasid" ) )
	{
		$idvalue = $value->{id};
		$value = $value->{main};
	}
	my( $boxcount, $spacesid, $buttonid, $rows );

	if( $self->get_property( "multilang" ) )
	{
		$boxcount = 1;
		$spacesid = $self->{name}.$suffix."_langspaces";
		$buttonid = $self->{name}.$suffix."_morelangspaces";

		$rows = $session->make_doc_fragment();
		if( $session->internal_button_pressed() )
		{
			if( defined $session->param( $spacesid ) )
			{
				$boxcount = $session->param( $spacesid );
			}
			if( $session->internal_button_pressed( $buttonid ) )
			{
				$boxcount += $self->{input_add_boxes};
			}
		}
		
		my( @force ) = @{$self->get_property( "requiredlangs" )};
		
		my %langstodo = ();
		foreach( keys %{$value} ) { $langstodo{$_}=1; }
		my %langlabels = ();
		foreach( EPrints::Config::get_languages() ) { $langlabels{$_}=EPrints::Config::lang_title($_); }
		foreach( @force ) { delete $langlabels{$_}; }
		my @langopts = ("", keys %langlabels );
		$langlabels{""} = "** Select Language **";
	
		my $i=1;
		my $langid;
		while( scalar(@force)>0 || $i<=$boxcount || scalar(keys %langstodo)>0)
		{
			my $langid = undef;
			my $forced = 0;
			if( scalar @force )
			{
				$langid = shift @force;
				$forced = 1;
				delete( $langstodo{$langid} );
			}
			elsif( scalar keys %langstodo )
			{
				$langid = ( keys %langstodo )[0];
				delete( $langstodo{$langid} );
			}
			
			my $langparamid = $self->{name}.$suffix."_".$i."_lang";
			my $langbit;
			if( $forced )
			{
				$langbit = $session->make_element( "span", class=>"requiredlang" );
				$langbit->appendChild( $session->make_element(
					"input",
					"accept-charset" => "utf-8",
					type => "hidden",
					name => $langparamid,
					value => $langid ) );
				$langbit->appendChild( $session->make_text( EPrints::Config::lang_title( $langid ) ) );
			}
			else
			{
				$langbit = $session->render_option_list(
					name => $langparamid,
					values => \@langopts,
					default => $langid,
					labels => \%langlabels );
			}
			
			## $langbit->appendChild( $session->make_text( " (LANGID:$langid)") );

			my $aux2;
			if( $self->get_property( "hasid" ) )	
			{
				$aux2 = $self->get_main_field()->_render_input_field_aux2( $session, $value->{$langid}, $suffix."_".$i );
			}
			else
			{
				$aux2 = $self->_render_input_field_aux2( $session, $value->{$langid}, $suffix."_".$i );
			}

			if( $self->is_type( "name" ) )
			{
				my $tr = $session->make_element( "tr" );
				$rows->appendChild( $tr );
				$tr->appendChild( $aux2 );
				my $td = $session->make_element( "td" );
				$td->appendChild( $langbit );
				$tr->appendChild( $td );
			}
			else
			{
				my $div = $session->make_element( "div" );# cjg style?
				$div->appendChild( $aux2 );
				#space? cjg
				$div->appendChild( $langbit );
				$rows->appendChild( $div );
			}
			
			++$i;
		}
				
		$boxcount = $i-1;

	}
	else
	{
		if( $self->is_type( "name" ) )
		{
			$rows = $session->make_element( "tr" );
		} 
		else
		{
			$rows = $session->make_doc_fragment();
		}
		my $aux2;
		if( $self->get_property( "hasid" ) )	
		{
			$aux2 = $self->get_main_field()->_render_input_field_aux2( $session, $value, $suffix );
		}
		else
		{
			$aux2 = $self->_render_input_field_aux2( $session, $value, $suffix );
		}
		$rows->appendChild( $aux2 );
	}

	my $block = $session->make_doc_fragment();
	if( $self->is_type( "name" ) )
	{
		my( $table, $tr, $td, $th );
		$table = $session->make_element( "table" );
		$tr = $session->make_element( "tr" );
		$table->appendChild( $tr );
		
		unless( $session->get_archive()->get_conf( "hide_honourific" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( "lib/metafield:honourific" ) );
			$tr->appendChild( $th );
		}

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:given_names" ) );
		$tr->appendChild( $th );

		$th = $session->make_element( "th" );
		$th->appendChild( $session->html_phrase( "lib/metafield:family_names" ) );
		$tr->appendChild( $th );

		unless( $session->get_archive()->get_conf( "hide_lineage" ) )
		{
			$th = $session->make_element( "th" );
			$th->appendChild( $session->html_phrase( "lib/metafield:lineage" ) );
			$tr->appendChild( $th );
		}

		$table->appendChild( $rows );
		$block->appendChild( $table );
	}
	else
	{
		$block->appendChild( $rows );
	}

	if( $self->get_property( "multilang" ) )
	{
		$block->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			type => "hidden",
			name => $spacesid,
			value => $boxcount ) );
		$block->appendChild( $session->render_internal_buttons(
			$buttonid => $session->phrase( "lib/metafield:more_langs" ) ) );
	}

	if( $self->get_property( "hasid" ) )
	{
		my $div;
		$div = $session->make_element( "div", class=>"formfieldidname" );
		$div->appendChild( $session->make_text( $self->get_id_field()->display_name( $session ).":" ) );
		$block->appendChild( $div );
		$div = $session->make_element( "div", class=>"formfieldidinput" );
		$block->appendChild( $div );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $self->{name}.$suffix."_id",
			value => $idvalue,
			size => $self->{input_id_cols} ) );
		$block->appendChild( $div );
	}
	
	return $block;
}

sub _render_input_field_aux2
{
	my( $self, $session, $value, $suffix ) = @_;

# not return DIVs? cjg (currently some types do some don't)

	my $frag = $session->make_doc_fragment();
	if( $self->is_type( "longtext" ) || $self->{input_style} eq "textarea" )
	{
		my( $div , $textarea , $id );
 		$id = $self->{name}.$suffix;
		$div = $session->make_element( "div" );	
		$textarea = $session->make_element(
			"textarea",
			name => $id,
			rows => $self->{input_rows},
			cols => $self->{input_cols},
			wrap => "virtual" );
		$textarea->appendChild( $session->make_text( $value ) );
		$div->appendChild( $textarea );
		
		$frag->appendChild( $div );
	}
	elsif( $self->is_type( "text", "url", "int", "email", "year","secret" ) )
	{
		my( $maxlength, $size, $div, $id );
 		$id = $self->{name}.$suffix;
		if( $session->internal_button_pressed() )
		{
			$value = $session->param( $id );
		}

		if( $self->is_type( "int" ) )
		{
			$maxlength = $self->{digits};
		}
		elsif( $self->is_type( "year" ) )
		{
			$maxlength = 4;
		}
		else
		{
			$maxlength = $self->{maxlength};
		}

		$size = ( $maxlength > $self->{input_cols} ?
					$self->{input_cols} : 
					$maxlength );

		$frag->appendChild( $session->make_element(
			"input",
			type => ($self->is_type( "secret" )?"password":undef),
			"accept-charset" => "utf-8",
			name => $id,
			value => $value,
			size => $size,
			maxlength => $maxlength ) );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		#cjg OTHER METHOD THAN CHECKBOX? TRUE/FALSE MENU?
		my( $div , $id);
 		$id = $self->{name}.$suffix;
		

		$div = $session->make_element( "div" );	
		if( $self->{input_style} eq "menu" )
		{
			my %settings = (
				height=>2,
				values=>[ "TRUE", "FALSE" ],
				labels=>{
					TRUE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_TRUE"),
					FALSE=> $session->phrase( $self->{confid}."_fieldopt_".$self->{name}."_FALSE")
				},
				name=>$id,
				default=>$value
			);
			$div->appendChild( $session->render_option_list( %settings ) );
		}
		elsif( $self->{input_style} eq "radio" )
		{
			# render as radio buttons

			my $true = $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "radio",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "TRUE" );
			my $false = $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "radio",
				checked=>( defined $value && $value ne 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "FALSE" );
			$div->appendChild( $session->html_phrase(
				$self->{confid}."_radio_".$self->{name},
				true=>$true,
				false=>$false ) );
		}
		else
		{
			$div->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				type => "checkbox",
				checked=>( defined $value && $value eq 
						"TRUE" ? "checked" : undef ),
				name => $id,
				value => "TRUE" ) );
		}
		$frag->appendChild( $div );
	}
	elsif( $self->is_type( "name" ) )
	{
		my( $td );
		my @namebits;
		unless( $session->get_archive()->get_conf( "hide_honourific" ) )
		{
			push @namebits, "honourific";
		}
		push @namebits, "given", "family";
		unless( $session->get_archive()->get_conf( "hide_lineage" ) )
		{
			push @namebits, "lineage";
		}
	
		foreach( @namebits )
		{
			my $size = $self->{input_name_cols}->{$_};
			$td = $session->make_element( "td" );
			$frag->appendChild( $td );
			$td->appendChild( $session->make_element(
				"input",
				"accept-charset" => "utf-8",
				name => $self->{name}.$suffix."_".$_,
				value => $value->{$_},
				size => $size,
				maxlength => $self->{maxlength} ) );
		}

	}
	elsif( $self->is_type( "pagerange" ) )
	{
		my( $div , @pages , $fromid, $toid );
		@pages = split /-/, $value if( defined $value );
 		$fromid = $self->{name}.$suffix."_from";
 		$toid = $self->{name}.$suffix."_to";
		
		$div = $session->make_element( "div" );	

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $fromid,
			value => $pages[0],
			size => 6,
			maxlength => 10 ) );

		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( "lib/metafield:to" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $toid,
			value => $pages[1],
			size => 6,
			maxlength => 10 ) );
		$frag->appendChild( $div );

	}
	elsif( $self->is_type( "date" ) )
	{
		my( $div, $yearid, $monthid, $dayid );
		$div = $session->make_element( "div" );	
		my( $year, $month, $day ) = ("", "", "");
		if( defined $value && $value ne "" )
		{
			($year, $month, $day) = split /-/, $value;
			if( $month == 0 )
			{
				($year, $month, $day) = ("", "00", "");
			}
		}
 		$dayid = $self->{name}.$suffix."_day";
 		$monthid = $self->{name}.$suffix."_month";
 		$yearid = $self->{name}.$suffix."_year";

		$div->appendChild( $session->html_phrase( "lib/metafield:year" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $yearid,
			value => $year,
			size => 4,
			maxlength => 4 ) );

		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( "lib/metafield:month" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->render_option_list(
			name => $monthid,
			values => \@monthkeys,
			default => $month,
			labels => $self->_month_names( $session ) ) );
		$div->appendChild( $session->make_text(" ") );
		$div->appendChild( $session->html_phrase( "lib/metafield:day" ) );
		$div->appendChild( $session->make_text(" ") );

		$div->appendChild( $session->make_element(
			"input",
			"accept-charset" => "utf-8",
			name => $dayid,
			value => $day,
			size => 2,
			maxlength => 2 ) );
		$frag->appendChild( $div );
	}
	else
	{
		$frag->appendChild( $session->make_text( "???" ) );
		$session->get_archive()->log( "Don't know how to render input".
					  "field of type: ".$self->get_type() );
	}
	return $frag;
}

#WP1: BAD
sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @monthkeys )
	{
		$months->{$month} = EPrints::Utils::get_month_label( $session, $month );
	}

	return $months;
}

######################################################################
#
# $value = form_value( $field )
#
#  A complement to param(). This reads in values from the form,
#  and puts them back into a value appropriate for the field type.
#
######################################################################

sub form_value
{
	my( $self, $session ) = @_;

	my $value = $self->_form_value_aux0( $session );

	if( defined $self->{fromform} )
	{
		$value = &{$self->{fromform}}( $value, $session );
	}

	return $value;
}

sub _form_value_aux0
{
	my( $self, $session ) = @_;
	
	if( $self->is_type( "set", "subject", "datatype" ) ) 
	{
		my @values = $session->param( $self->{name} );
		
		if( scalar( @values ) == 0 )
		{
			return undef;
		}
		if( $self->get_property( "multiple" ) )
		{
			# Make sure all fields are unique
			# There could be two options with the same id,
			# especially in "subject"
			my %v;
			foreach( @values ) { $v{$_}=1; }
			@values = keys %v;
			return \@values;
		}
	
		return $values[0];
	}

	if( $self->get_property( "multiple" ) )
	{
		my @values = ();
		my $boxcount = $session->param( $self->{name}."_spaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $value = $self->_form_value_aux1( $session, $i );
			if( defined $value )
			{
				push @values, $value;
			}
		}
		if( scalar @values == 0 )
		{
			return undef;
		}
		return \@values;
	}

	return $self->_form_value_aux1( $session );
}

sub _form_value_aux1
{
	my( $self, $session, $n ) = @_;

	my $suffix = "";
	$suffix = "_$n" if( defined $n );

	my $value;
	if( $self->get_property( "multilang" ) )
	{
		$value = {};
		my $boxcount = $session->param( $self->{name}.$suffix."_langspaces" );
		$boxcount = 1 if( $boxcount < 1 );
		my $i;
		for( $i=1; $i<=$boxcount; ++$i )
		{
			my $subvalue = $self->_form_value_aux2( $session, $suffix."_".$i );
			my $langid = $session->param( $self->{name}.$suffix."_".$i."_lang" );
			if( $langid eq "" ) { $langid = "_".$i; }
			if( defined $subvalue )
			{
				$value->{$langid} = $subvalue;
#cjg -- does not check that this is a valid langid...
			}
	print STDERR ".....................tick: ".$self->{name}.$suffix."_".$i."_lang\n";
		}
#print STDERR "!!".Dumper( $value ) if( $self->{name} =~ m/editor/ );
		$value = undef if( scalar keys %{$value} == 0 );
	}
	else
	{
		$value = $self->_form_value_aux2( $session, $suffix );
	}
#print STDERR ">>".Dumper( $value ) if( $self->{name} =~ m/editor/ );
	if( $self->get_property( "hasid" ) )
	{
		my $id = $session->param( $self->{name}.$suffix."_id" );
		$value = { id=>$id, main=>$value };
	}
	return undef unless( EPrints::Utils::is_set( $value ) );

	return $value;
}

sub _form_value_aux2
{
	my( $self, $session, $suffix ) = @_;
	
	if( $self->is_type( "text", "url", "int", "email", "longtext", "year", "secret", "id" ) )
	{
		my $value = $session->param( $self->{name}.$suffix );
		return undef if( $value eq "" );
		if( !$self->is_type( "longtext" ) && $self->{input_style} eq "textarea" )
		{
			$value=~s/[\n\r]+/ /gs;
		}
		return $value;
	}
	elsif( $self->is_type( "pagerange" ) )
	{
		my $from = $session->param( $self->{name}.$suffix."_from" );
		my $to = $session->param( $self->{name}.$suffix."_to" );

		if( !defined $to || $to eq "" )
		{
			return( $from );
		}
		
		return( $from . "-" . $to );
	}
	elsif( $self->is_type( "boolean" ) )
	{
		my $form_val = $session->param( $self->{name}.$suffix );
		return ( defined $form_val ? "TRUE" : "FALSE" );
	}
	elsif( $self->is_type( "date" ) )
	{
		my $day = $session->param( $self->{name}.$suffix."_day" );
		my $month = $session->param( 
					$self->{name}.$suffix."_month" );
		my $year = $session->param( $self->{name}.$suffix."_year" );

		if( defined $day && $month ne "00" && defined $year )
		{
			return $year."-".$month."-".$day;
		}
		return undef;
	}
	elsif( $self->is_type( "name" ) )
	{
		my $data = {};
		foreach( "honourific", "given", "family", "lineage" )
		{
			$data->{$_} = $session->param( $self->{name}.$suffix."_".$_ );
		}
		if( EPrints::Utils::is_set( $data ) )
		{
			return $data;
		}
		return undef;
	}
	else
	{
		$session->get_archive()->log( 
			"Error: can't do _form_value_aux2 on type ".
			"'".$self->{type}."'" );
		return undef;
	}	
}

# cjg this function should return the most useful version of a field if it
# is a multilang field. Initially the search order will be:
# language of 'session'
# default language
# any language
sub most_local
{
	#cjg not done yet
	my( $self, $session, $value ) = @_;
	my $bestvalue =  EPrints::Session::best_language( $session->get_archive(), $session->get_langid(), %{$value} );
	return $bestvalue;
}

sub get_id_field
{
	my( $self ) = @_;
	# only meaningful to call this on "hasid" fields
	#cjg SHould log an issue if otherwise?
	#returns undef for non-id fields.
	return unless( $self->get_property( "hasid" ) );
	my $idfield = $self->clone();
	$idfield->set_property( "multilang", 0 );
	$idfield->set_property( "hasid", 0 );
	$idfield->set_property( "type", "id" );
	$idfield->set_property( "idpart", 1 );
	return $idfield;
}

sub get_main_field
{
	my( $self ) = @_;
	# only meaningful to call this on "hasid" fields
	return unless( $self->get_property( "hasid" ) );

	my $idfield = $self->clone();
	$idfield->set_property( "hasid", 0 );
	$idfield->set_property( "mainpart", 1 );
	return $idfield;
}

# Which bit do we care about in an eprints value (the id, main, or all of it?)
sub which_bit
{
	my( $self, $value ) = @_;

	if( $self->get_property( "idpart" ) )
	{
		return $value->{id};
	}
	if( $self->get_property( "mainpart" ) )
	{
		return $value->{main};
	}
	return $value;
}

sub get_sql_name
{
	my( $self ) = @_;

	if( $self->get_property( "idpart" ) )
	{
		return $self->{name}."_id";
	}
	if( $self->get_property( "mainpart" ) )
	{
		#cjg I'm not at all sure about if the main
		# bit should be the plain name or name_main
		#return $self->{name}."_main";

		return $self->{name};
	}
	return $self->{name};
}

sub is_browsable
{
	my( $self ) = @_;
	
	# Can never browse:
	# pagerange , secret , longtext

        # Can't yet browse:
        # boolean , text,  langid ,name 

	return $self->is_type( "set", "subject", "datatype", "date", "int", "year", "id", "email", "url", "text" );

}

sub get_values
{
	my( $self, $session, %opts ) = @_;

	if( $self->is_type( "set" ) )
	{
		return @{$self->get_property( "options" )};
	}

	if( $self->is_type( "subject" ) )
	{
		my $topsubj = EPrints::Subject->new(
			$session,
			$self->get_property( "top" ) );
		my ( $pairs ) = $topsubj->get_subjects( 0 , !$opts{hidetoplevel} , $opts{nestids} );
		my @values = ();
		my $pair;
		foreach $pair ( @{$pairs} )
		{
			push @values, $pair->[0];
		}
		return @values;
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
				$self->{datasetid} );	
		return @{$ds->get_types()};
	}

	if( $self->is_type( "date", "int", "year", "id", "email", "url" , "text" ) )
	{
		return $session->get_db()->get_values( $self );
	}

	# should not have called this function without checking is_browsable
	return ();
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	if( !EPrints::Utils::is_set( $value ) )
	{
		return $session->phrase( "lib/metafield:unspecified" );
	}

	if( $self->is_type( "set" ) )
	{
		return $self->display_option( $session, $value );
	}

	if( $self->is_type( "subject" ) )
	{
		my $subj = EPrints::Subject->new( $session, $value );
		return $subj->get_name();
	}

	if( $self->is_type( "datatype" ) )
	{
		my $ds = $session->get_archive()->get_dataset( 
				$self->{datasetid} );	
		return $ds->get_type_name( $session, $value );
	}

	if( $self->is_type( "date" ) )
	{
		return EPrints::Utils::render_date( $session, $value );
	}

	# In some contexts people migth want the URL or email to be a link
	# but usually it's going to be a label, which can be a link in
	# itself. Which is weird, but I doubt anyone will browse by URL
	# anyway...

	if( $self->is_type( "int", "year", "email", "url" ) )
	{
		return $value;
	}

	if( $self->is_type( "id" ) )
	{
		return $session->get_archive()->call( "id_label", $self, $session, $value );
	}

	return "???".$value."???";
}

sub get_dataset
{
	my( $self ) = @_;

	return $self->{dataset};
}		

sub ordervalue
{
	my( $self , $value , $archive , $langid ) = @_;

	return "" if( !defined $value );

	if( !$self->get_property( "multiple" ) )
	{
		return $self->ordervalue_aux1( $value , $archive , $langid );
	}

	my @r = ();	
	foreach( @$value )
	{
		push @r, $self->ordervalue_aux1( $_ , $archive , $langid );
	}
	return join( ":", @r );
}

sub ordervalue_aux1
{
	my( $self , $value , $archive , $langid ) = @_;

	return "" if( !defined $value );

	if( !$self->get_property( "multilang" ) )
	{
		return $self->ordervalue_aux2( $value );
	}
	return $self->ordervalue_aux2( 
		EPrints::Session::best_language( 
			$archive,
			$langid,
			%{$value} ) );
}

sub ordervalue_aux2
{
	my( $self , $value ) = @_;

	return "" if( !defined $value );

	my $v = $value;
	if( $self->get_property( "idpart" ) )
	{
		$v = $value->{id};
	}
	if( $self->get_property( "mainpart" ) )
	{
		$v = $value->{main};
	}
	return $self->ordervalue_aux3( $v );
}

sub ordervalue_aux3
{
	my( $self , $value ) = @_;

	return "" if( !defined $value );

	## cjg
	# Subject & set should probably be expanded out into their cosmetic
	# names.

	if( $self->is_type( "name" ) )
	{
		my @a;
		foreach( "family", "lineage", "given", "honourific" )
		{
			if( defined $value->{$_} )
			{
				push @a, $value->{$_};
			}
			else
			{
				push @a, "";
			}
		}
		return join( "," , @a );
	}
	return $value;
}


sub get_property_default
{
	my( $self, $property ) = @_;

	my $archive = $self->get_dataset()->get_archive();

	foreach( 
		"digits", 
		"input_rows", 
		"input_cols", 
		"input_name_cols",
		"input_id_cols",
		"input_add_boxes", 
		"input_boxes" )
	{
		if( $property eq $_ )
		{
			return $archive->get_conf( "field_defaults" )->{$_};
		}
	}	

	if( $property eq "maxlength" )
	{
		return $archive->get_conf( "varchar_size" );
	}

	return [] if( $property eq "requiredlangs" );

	return 0 if( $property eq "input_style" );
	return 0 if( $property eq "hasid" );
	return 0 if( $property eq "multiple" );
	return 0 if( $property eq "multilang" );
	return 0 if( $property eq "required" );
	return 0 if( $property eq "showall" );
	return 0 if( $property eq "showtop" );
	return 0 if( $property eq "idpart" );
	return 0 if( $property eq "mainpart" );

	return "subjects" if( $property eq "top" );

	return undef if( $property eq "confid" );
	return undef if( $property eq "fromform" );
	return undef if( $property eq "toform" );
	return undef if( $property eq "render_single_value" );
	return undef if( $property eq "render_value" );

	EPrints::Config::abort( "Unknown property in get_property_default: $property" );
};

		
1;
