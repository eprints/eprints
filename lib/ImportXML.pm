######################################################################
#
# EPrints::ImportXML
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

B<EPrints::ImportXML> - Module to assist importing data into EPrints 
from XML files.

=head1 DESCRIPTION

ImportXML parses an XML file in the eprints data format and turns
each record into an eprint object which is then passed to a function
for further action.

=over 4

=cut

######################################################################

package EPrints::ImportXML;

use XML::Parser;

# function will be called once for each object described by the XML
# file with the session handle, the table and whatever kind of 
# eprint object.

# this module creates an extra property of the parser, calling it
# "eprints". This is used to pass around state information including
# the session handle and the current object.

#cjg NEEDS to spot ID!

#cjg Needs to be able to specify default language (to stop it doing 
# "?" )


######################################################################
=pod

=item EPrints::ImportXML::import_file( $session, $filename, $function, 
$dataset, $info )

Map all the eprints data objects described in the XML file $filename
onto the function $function. $function is called once for each object
created from the XML.

Objects are only created. If they should be stored to disk then the
function they are passed to must handle that. 

$info is a hash of values which will be passed to the function 
specified in $function (which is safer than global variables).

$function should be a reference to a function. It will be passed the
following parameters:

 &{$function}( $session, $dataset, $item, $info );

where $session, $dataset and $info are the values passed to import_file
and $item is an item of the type $dataset which has been created from
the XML.

=cut
######################################################################

sub import_file
{
	my( $session , $filename , $function, $dataset, $info ) = @_;
	my $parser = new XML::Parser(
		Style => "Subs", 
		ErrorContext => 5,
		Handlers => { 
			Start => \&_handle_start, 
			End => \&_handle_end,
			Char => \&_handle_char 
		} );
	$parser->{eprints} = {};
	$parser->{eprints}->{session} = $session;
	$parser->{eprints}->{theirinfo} = $info;
	$parser->{eprints}->{function} = $function;
	$parser->{eprints}->{fields} = {};
	foreach( $dataset->get_fields() )
	{
		$parser->{eprints}->{fields}->{$_->{name}}=$_;
	}
	$parser->{eprints}->{dataset} = $dataset;
	$parser->parsefile( $filename );
}

######################################################################
# 
# EPrints::ImportXML::_handle_start( $parser, $tag, %params )
#
# undocumented
#
######################################################################

sub _handle_start
{
	my( $parser , $tag , %params ) = @_;
	$tag = uc($tag);
	if( $tag eq "EPRINTSDATA" )
	{
		if( $parser->{eprints}->{started} )
		{
			$parser->xpcroak( "EPRINTSDATA inside EPRINTSDATA" );
		}
		$parser->{eprints}->{started} = 1;
	
		return;
	}

	if( $tag eq "RECORD" )
	{
		if( defined $parser->{eprints}->{data} )
		{
			$parser->xpcroak( "RECORD inside RECORD" );
		}
		$parser->{eprints}->{data} = {};
		return;
	}	

	if( $tag eq "FIELD" )
	{
		if( defined $parser->{eprints}->{currentfield} )
		{
			$parser->xpcroak( "$tag inside other field" );
		}
		#elsif( !defined $parser->{eprints}->{fields}->{$params{name}} )
		#{
		#	$parser->xpcroak( "unknown field: $params{name}" );
		#}
		else
		{
			$parser->{eprints}->{currentfield} = $params{name};
			$parser->{eprints}->{currentdata} = "";
			$parser->{eprints}->{currentid} = $params{id};
		}

		return;
	}

	if( $tag eq "PART" )
	{
		if( !$parser->{eprints}->{currentspecial} )
		{
			$parser->{eprints}->{currentdata} = {};
			$parser->{eprints}->{currentspecial} = 1;
		}
		$parser->{eprints}->{currentspecialpart} = lc $params{name};
		$parser->{eprints}->{currentdata}->{lc $params{name}} = "";
		return;
	}
	
	if( $tag eq "LANG" )
	{
		if( !defined $parser->{eprints}->{currentmultilang} )
		{
			$parser->{eprints}->{currentmultilang} = {};
		}
		$parser->{eprints}->{currentlang} = lc $params{id};
		$parser->{eprints}->{currentdata} = "";
		return;
	}
	
	$parser->xpcroak( "Unknown tag: $tag" );
}



######################################################################
# 
# EPrints::ImportXML::_handle_end( $parser, $tag )
#
# undocumented
#
######################################################################

sub _handle_end
{
	my ( $parser , $tag ) = @_;
	$tag = uc($tag);
	if ( $tag eq "EPRINTSDATA" )
	{
		delete $parser->{eprints}->{ds};
		delete $parser->{eprints}->{fields};
		return;
	}

	if ( $tag eq "RECORD" )
	{

		my $ds = $parser->{eprints}->{dataset};
		my $item = $ds->make_object(
			$parser->{eprints}->{session},
			$parser->{eprints}->{data} );

	
		&{$parser->{eprints}->{function}}( 
			$parser->{eprints}->{session}, 
			$parser->{eprints}->{dataset},
			$item,
			$parser->{eprints}->{theirinfo});

		delete $parser->{eprints}->{data};
		return;
	}

	if( $tag eq "FIELD" )
	{
#cjg What non OO it has... (call the damn methods, chris!)
		my $fielddata = $parser->{eprints}->{currentdata};
		if( $fielddata eq "" ) { $fielddata = undef; }
		my $currfield = $parser->{eprints}->{currentfield};
		if( $parser->{eprints}->{fields}->{$currfield}->{multilang} )
		{
			my $ml = $parser->{eprints}->{currentmultilang};
			if( !defined $ml ) { $ml = {}; }

			if( defined $fielddata && $fielddata !~ m/^\s*$/ ) { $ml->{"?"} = $fielddata; }
			
			$fielddata = $ml;
		}
		if( $parser->{eprints}->{fields}->{$currfield}->{hasid} )
		{
			$fielddata = {
				main => $fielddata,
				id => $parser->{eprints}->{currentid}
			};
		}
			
		if( $parser->{eprints}->{fields}->{$currfield}->{multiple} )
		{
			push @{ $parser->{eprints}->{data}->{$currfield} }, $fielddata;
		} 
		else
		{
			$parser->{eprints}->{data}->{$currfield}=$fielddata;
		}
		delete $parser->{eprints}->{currentid};
		delete $parser->{eprints}->{currentfield};
		delete $parser->{eprints}->{currentdata};
		delete $parser->{eprints}->{currentmultilang};
		delete $parser->{eprints}->{currentlang};
		delete $parser->{eprints}->{currentspecial};
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}

	if( $tag eq "PART" )
	{
		delete $parser->{eprints}->{currentspecialpart};
		return;
	}
	if( $tag eq "LANG" )
	{
		$parser->{eprints}->{currentmultilang}->{ $parser->{eprints}->{currentlang} } = $parser->{eprints}->{currentdata};
		$parser->{eprints}->{currentdata} = "";
		return;
	}
	$parser->xpcroak( "Unknown end tag: $tag" );
}

######################################################################
# 
# EPrints::ImportXML::_handle_char( $parser, $text )
#
# undocumented
#
######################################################################

sub _handle_char
{
	my( $parser , $text ) = @_;

	if( !defined $parser->{eprints}->{currentdata} )
	{
		return;
	}

	if( $parser->{eprints}->{currentspecial} )
	{
		if( !defined $parser->{eprints}->{currentspecialpart} )
		{
			return;
		}
		$parser->{eprints}->{currentdata}->
			{$parser->{eprints}->{currentspecialpart}} .= $text;
	}
	else
	{	
		$parser->{eprints}->{currentdata}.= $text;
	}
	
}

1;
######################################################################
=pod
=back

=head1 XML File Format

The top level element is "eprintsdata" which contains zero or more "record"
elements.

A record element represents a single eprints object and contains zero or more
field elements.

A field element has the attribute "name" which is the name of a field in the 
dataset. The contents of the field element describes the value of this field
in this record. Some eprints fields may be I<multiple> in which case multiple
values can be expressed by having several "field" elements with the same name
attribute in a single "record". A field element may contain nothing OR some
text OR "part" elements OR "name" elements. A field element may also have
an "id" attribute which is the unique id of this value- a user id number, or
a isbn or some such.

A part element represents part of a value in a name field. It must have the
attribute "name" which must be set to one of "lineage", "honourific", "family"
or "given". It may contain text or nothing.

A lang element represents a version of the value of the field in a certain 
language. It may contain text or nothing. It has the required attribute "id"
which is the ISO language code.

Example of a file with a single record with a multiple name field (with
ids) named "authors", a multiple subjects field named "subjects", a multilang 
text field named "title" and a year field named "year".

 <eprintsdata>
   <record>
     <field id="cjg" name="authors">
       <part name="family">Gutteridge</part>
       <part name="given">Christopher</part>
     </field>
     <field id="mv" name="authors">
       <part name="honourific">Dr.</part>
       <part name="given">Marvin</part>
       <part name="family">Fenderson</part>
     </field>
     <field name="year">1993</field>
     <field name="subjects">foo</field>
     <field name="subjects">bar</field>
     <field name="subjects">baz</field>
     <field name="title">
       <lang id="en">The Thing</lang>
       <lang id="de">da Thung</lang>
       <lang id="fr">l'Thingu</lang>
     </field>
   </record>
 </eprintsdata> 

=cut
######################################################################


