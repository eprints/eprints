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

# Month names
my %monthnames =
(
	"00"     => "Unspecified",
	"01"     => "January",
	"02"     => "February",
	"03"     => "March",
	"04"     => "April",
	"05"     => "May",
	"06"     => "June",
	"07"     => "July",
	"08"     => "August",
	"09"     => "September",
	"10"     => "October",
	"11"     => "November",
	"12"     => "December"
);
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
sub isType
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
	return $self->isType( "text","longtext","url","email" );
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

	if( $self->isType( "text" , "int" , "pagerange" , "year" ) )
	{
		# Render text
		return $session->makeText( $value );
	}

	if( $self->isType( "name" ) )
	{
		return $session->makeText(
			EPrints::Name::format_names( $value ) );
	}

	if( $self->isType( "eprinttype" ) )
	{
		$html = $self->{labels}->{$value} if( defined $value );
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
	}
	elsif( $self->isType( "boolean" ) )
	{
		$html = $self->{session}->makeText("UNSPECIFIED") unless( defined $value );
		$html = ( $value eq "TRUE" ? "Yes" : "No" ) if( defined $value );
	}
	elsif( $self->isType( "longtext" ) )
	{
		$html = ( defined $value ? $value : "" );
		$html =~ s/\r?\n\r?\n/<BR><BR>\n/s;
	}
	elsif( $self->isType( "date" ) )
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
				$html = $elements[2]." ".$monthnames{$elements[1]}." ".$elements[0];
			}
		}
		else
		{
			$html = "UNSPECIFIED";
		}
	}
	elsif( $self->isType( "url" ) )
	{
		$html = "<A HREF=\"$value\">$value</A>" if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->isType( "email" ) )
	{
		$html = "<A HREF=\"mailto:$value\">$value</A>"if( defined $value );
		$html = "" unless( defined $value );
	}
	elsif( $self->isType( "subject" ) )
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
	elsif( $self->isType( "set" ) )
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
	elsif( $self->isType( "username" ) )
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

