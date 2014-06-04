######################################################################
#
# EPrints::MetaField::Date;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Date> - no description

=head1 DESCRIPTION

not done

=over 4

=cut


package EPrints::MetaField::Date;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField );
}

use EPrints::MetaField;

sub get_sql_names
{
	my( $self ) = @_;

	return map { $self->get_name . "_" . $_ } qw( year month day );
}

# parse either ISO or our format and output our value
sub _build_value
{
	my( $self, $value ) = @_;

	return undef if !defined $value;

	my @parts = split /[-: TZ]/, $value;

	$value = "";
	$value .= sprintf("%04d",$parts[0]) if( defined $parts[0] );
	$value .= sprintf("-%02d",$parts[1]) if( defined $parts[1] );
	$value .= sprintf("-%02d",$parts[2]) if( defined $parts[2] );

	return $value;
}

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	my @parts = grep { defined $_ } splice(@$row,0,3);

	return undef if !@parts;

	return $self->_build_value( join(' ', @parts) );
}

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	my @parts;
	@parts = split /[-TZ: ]/, $value if defined $value;
	@parts = @parts[0..2];

	return @parts;
}

sub get_sql_type
{
	my( $self, $session ) = @_;

	my @parts = $self->get_sql_names;

	for(@parts)
	{
		$_ = $session->get_database->get_column_type(
			$_,
			EPrints::Database::SQL_SMALLINT,
			0, # force notnull
			undef,
			undef,
			$self->get_sql_properties,
		);
	}

	return @parts;
}

	
@EPrints::MetaField::Date::MONTHKEYS = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

sub _month_names
{
	my( $self , $session ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @EPrints::MetaField::Date::MONTHKEYS )
	{
		$months->{$month} = EPrints::Time::get_month_label( 
			$session, 
			$month );
	}

	return $months;
}

sub get_unsorted_values
{
	my( $self, $session, $dataset ) = @_;

	my $values = $session->get_database->get_values( $self, $dataset );

	my $res = $self->{render_res};

	if( $res eq "day" )
	{
		return $values;
	}

	my $l = 10;
	if( $res eq "month" ) { $l = 7; }
	if( $res eq "year" ) { $l = 4; }
		
	my %ov = ();
	foreach my $value ( @{$values} )
	{
		if( !defined $value )
		{
			$ov{undef} = 1;
			next;
		}
		$ov{substr($value,0,$l)}=1;
	}
	my @outvalues = keys %ov;
	return \@outvalues;
}

sub get_id_from_value
{
	my( $self, $session, $value ) = @_;

	return 'NULL' if !EPrints::Utils::is_set( $value );
	my $id = $self->SUPER::get_id_from_value( $session, $value );

	my $res = $self->{render_res};

	return substr($id,0,4) if $res eq "year";
	return substr($id,0,7) if $res eq "month";
	return substr($id,0,10) if $res eq "day";

	return $res;
}

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return $self->render_single_value( $session, $value );
}

# overridden, date searches being EX means that 2000 won't match 
# 2000-02-21
sub get_search_conditions
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	if( $match eq "SET" )
	{
		return $self->SUPER::get_search_conditions( @_[1..$#_] );
	}

	if( $match eq "EX" )
	{
		if( !EPrints::Utils::is_set( $search_value ) )
		{	
			return EPrints::Search::Condition->new( 
					'is_null', 
					$dataset, 
					$self );
		}
	}

	return $self->get_search_conditions_not_ex(
			$session, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

	# DATETIME
	# DATETIME-
	# -DATETIME
	# DATETIME-DATETIME
	# DATETIME := YEAR-MON-DAY{'T',' '}HOUR:MIN:SEC{'Z'}

	return $self->EPrints::MetaField::Int::get_search_conditions_not_ex(
		$session, $dataset, $search_value, $match, $merge, $search_mode
	);
}

sub get_search_group { return 'date'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "day";
	$defaults{text_index} = 0;
	$defaults{regexp} = qr/\d\d\d\d(?:-\d\d(?:-\d\d)?)?/;
	return %defaults;
}

sub trim_date
{
	my( $self, $date, $resolution ) = @_;

	return undef unless defined $date;

	return substr( $date, 0, 4  ) if $resolution == 1;
	return substr( $date, 0, 7  ) if $resolution == 2;
	return substr( $date, 0, 10 ) if $resolution == 3;
	return substr( $date, 0, 13 ) if $resolution == 4;
	return substr( $date, 0, 16 ) if $resolution == 5;
	return substr( $date, 0, 19 ) if $resolution == 6;

	return $date;
}

sub ordervalue_basic
{
	my( $self , $value ) = @_;

	return $self->_build_value( $value );
}

sub set_value
{
	my( $self, $dataobj, $value ) = @_;

	# reformat date/time values so they are always consistently stored
	local $_;
	for(ref($value) eq "ARRAY" ? @$value : $value)
	{
		$_ = $self->_build_value( $_ );
	}

	$self->SUPER::set_value( $dataobj, $value );
}

sub get_resolution
{
	my( $self, $date ) = @_;

	return 0 unless defined $date;

	my $l = length( $date );

	return 0 if $l == 0;
	return 1 if $l == 4;
	return 2 if $l == 7;
	return 3 if $l == 10;
	return 4 if $l == 13;
	return 5 if $l == 16;
	return 6;
}

sub should_reverse_order { return 1; }

######################################################################
1;

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

