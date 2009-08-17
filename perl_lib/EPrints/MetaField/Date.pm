######################################################################
#
# EPrints::MetaField::Date;
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

our $REGEXP_DATETIME = qr/\d\d\d\d(?:-\d\d(?:-\d\d(?:[ T]\d\d(?::\d\d(?::\d\dZ?)?)?)?)?)?/;

sub get_sql_names
{
	my( $self ) = @_;

	return map { $self->get_name . "_" . $_ } qw( year month day );
}

sub value_from_sql_row
{
	my( $self, $handle, $row ) = @_;

	my @parts = splice(@$row,0,3);

	my $value = "";
	$value.= sprintf("%04d",$parts[0]) if( defined $parts[0] );
	$value.= sprintf("-%02d",$parts[1]) if( defined $parts[1] );
	$value.= sprintf("-%02d",$parts[2]) if( defined $parts[2] );

	return $value;
}

sub sql_row_from_value
{
	my( $self, $handle, $value ) = @_;

	my @parts;
	@parts = split /[-]/, $value if defined $value;
	push @parts, undef while scalar(@parts) < 3;

	return @parts;
}

sub get_sql_type
{
	my( $self, $handle ) = @_;

	my @parts = $self->get_sql_names;

	for(@parts)
	{
		$_ = $handle->get_database->get_column_type(
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

sub render_single_value
{
	my( $self, $handle, $value ) = @_;

	my $res = $self->{render_res};
	my $l = 10;
	$l = 7 if( defined $res && $res eq "month" );
	$l = 4 if( defined $res && $res eq "year" );

	if( $self->{render_style} eq "short" )
	{
		return EPrints::Time::render_short_date( $handle, substr( $value,0,$l ) );
	}
	return EPrints::Time::render_date( $handle, substr( $value,0,$l ) );
}
	
@EPrints::MetaField::Date::MONTHKEYS = ( 
	"00", "01", "02", "03", "04", "05", "06",
	"07", "08", "09", "10", "11", "12" );

sub _month_names
{
	my( $self , $handle ) = @_;
	
	my $months = {};

	my $month;
	foreach $month ( @EPrints::MetaField::Date::MONTHKEYS )
	{
		$months->{$month} = EPrints::Time::get_month_label( 
			$handle, 
			$month );
	}

	return $months;
}

sub get_basic_input_elements
{
	my( $self, $handle, $value, $basename, $staff, $obj ) = @_;

	my( $frag, $div, $yearid, $monthid, $dayid );

	$frag = $handle->make_doc_fragment;
		
	my $min_res = $self->get_property( "min_resolution" );
	
	if( $min_res eq "month" || $min_res eq "year" )
	{	
		$div = $handle->make_element( "div", class=>"ep_form_field_help" );	
		$div->appendChild( $handle->html_phrase( 
			"lib/metafield:date_res_".$min_res ) );
		$frag->appendChild( $div );
	}

	$div = $handle->make_element( "div" );
	my( $year, $month, $day ) = ("", "", "");
	if( defined $value && $value ne "" )
	{
		($year, $month, $day) = split /-/, $value;
		$month = "00" if( !defined $month || $month == 0 );
		$day = "00" if( !defined $day || $day == 0 );
		$year = "" if( !defined $year || $year == 0 );
	}
 	$dayid = $basename."_day";
 	$monthid = $basename."_month";
 	$yearid = $basename."_year";

	$div->appendChild( 
		$handle->html_phrase( "lib/metafield:year" ) );
	$div->appendChild( $handle->make_text(" ") );

	$div->appendChild( $handle->render_noenter_input_field(
		class=>"ep_form_text",
		name => $yearid,
		id => $yearid,
		value => $year,
		size => 4,
		maxlength => 4 ) );

	$div->appendChild( $handle->make_text(" ") );

	$div->appendChild( 
		$handle->html_phrase( "lib/metafield:month" ) );
	$div->appendChild( $handle->make_text(" ") );
	$div->appendChild( $handle->render_option_list(
		name => $monthid,
		id => $monthid,
		values => \@EPrints::MetaField::Date::MONTHKEYS,
		default => $month,
		labels => $self->_month_names( $handle ) ) );

	$div->appendChild( $handle->make_text(" ") );

	$div->appendChild( 
		$handle->html_phrase( "lib/metafield:day" ) );
	$div->appendChild( $handle->make_text(" ") );
	my @daykeys = ();
	my %daylabels = ();
	for( 0..31 )
	{
		my $key = sprintf( "%02d", $_ );
		push @daykeys, $key;
		$daylabels{$key} = ($_==0?"?":$key);
	}
	$div->appendChild( $handle->render_option_list(
		name => $dayid,
		id => $dayid,
		values => \@daykeys,
		default => $day,
		labels => \%daylabels ) );

	$frag->appendChild( $div );
	
	return [ [ { el=>$frag } ] ];
}

sub get_basic_input_ids
{
	my( $self, $handle, $basename, $staff, $obj ) = @_;

	return( $basename."_day", $basename."_month", $basename."_year" );
}

sub form_value_basic
{
	my( $self, $handle, $basename ) = @_;
	
	my $day = $handle->param( $basename."_day" );
	my $month = $handle->param( 
				$basename."_month" );
	my $year = $handle->param( $basename."_year" );
	$month = undef if( !EPrints::Utils::is_set($month) || $month == 0 );
	$year = undef if( !EPrints::Utils::is_set($year) || $year == 0 );
	$day = undef if( !EPrints::Utils::is_set($day) || $day == 0 );
	my $r = undef;
	return $r if( !defined $year );
	$r .= sprintf( "%04d", $year );
	return $r if( !defined $month );
	$r .= sprintf( "-%02d", $month );
	return $r if( !defined $day );
	$r .= sprintf( "-%02d", $day );
	return $r;
}


sub get_unsorted_values
{
	my( $self, $handle, $dataset ) = @_;

	my $values = $handle->get_database->get_values( $self, $dataset );

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

sub get_ids_by_value
{
	my( $self, $handle, $dataset, %opts ) = @_;

	my $in_ids = $handle->get_database->get_ids_by_field_values( $self, $dataset, %opts );

	my $res = $self->{render_res};

	if( $res eq "day" )
	{
		return $in_ids;
	}

	my $l = 10;
	if( $res eq "month" ) { $l = 7; }
	if( $res eq "year" ) { $l = 4; }

	my $id_map = {};
	foreach my $value ( keys %{$in_ids} )
	{
		my $proc_v = "undef";
		if( defined $value )
		{
			$proc_v = substr($value,0,$l);
		}

		foreach my $id ( @{$in_ids->{$value}} )
		{
			$id_map->{$proc_v}->{$id} = 1;
		}
	}
	my $out_ids = {};
	foreach my $value ( keys %{$id_map} )
	{
		$out_ids->{$value} = [ keys %{$id_map->{$value}} ];
	}

	return $out_ids;
}

sub get_value_label
{
	my( $self, $handle, $value ) = @_;

	return EPrints::Time::render_date( $handle, $value );
}

sub render_search_input
{
	my( $self, $handle, $searchfield ) = @_;
	
	return $handle->render_input_field(
				class => "ep_form_text",
				type => "text",
				name => $searchfield->get_form_prefix,
				value => $searchfield->get_value,
				size => 21,
				maxlength => 21 );
}


sub from_search_form
{
	my( $self, $handle, $basename ) = @_;

	my $val = $handle->param( $basename );
	return unless defined $val;

	my $drange = $val;
	$drange =~ s/-(\d\d\d\d(-\d\d(-\d\d)?)?)$/-/;
	$drange =~ s/^(\d\d\d\d(-\d\d(-\d\d)?)?)(-?)$/$4/;

	if( $drange eq "" || $drange eq "-" )
	{
		return( $val );
	}
			
	return( undef,undef,undef, $handle->html_phrase( "lib/searchfield:date_err" ) );
}


sub render_search_value
{
	my( $self, $handle, $value ) = @_;

	# still not very pretty
	my $drange = $value;
	my $lastdate;
	my $firstdate;
	if( $drange =~ s/-($REGEXP_DATETIME)$/-/ )
	{	
		$lastdate = $1;
	}
	if( $drange =~ s/^($REGEXP_DATETIME)(-?)$/$2/ )
	{
		$firstdate = $1;
	}

	if( defined $firstdate && defined $lastdate )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_date_between",
			from => EPrints::Time::render_date( 
					$handle, 
					$firstdate ),
			to => EPrints::Time::render_date( 
					$handle, 
					$lastdate ) );
	}

	if( defined $lastdate )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_date_orless",
			to => EPrints::Time::render_date( 
					$handle,
					$lastdate ) );
	}

	if( defined $firstdate && $drange eq "-" )
	{
		return $handle->html_phrase(
			"lib/searchfield:desc_date_ormore",
			from => EPrints::Time::render_date( 
					$handle,
					$firstdate ) );
	}
	
	return EPrints::Time::render_date( $handle, $value );
}

# overridden, date searches being EX means that 2000 won't match 
# 2000-02-21
sub get_search_conditions
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;

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
			$handle, 
			$dataset, 
			$search_value, 
			$match, 
			$merge, 
			$search_mode );
}

sub get_search_conditions_not_ex
{
	my( $self, $handle, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	# DATETIME
	# DATETIME-
	# -DATETIME
	# DATETIME-DATETIME
	# DATETIME := YEAR-MON-DAY{'T',' '}HOUR:MIN:SEC{'Z'}

	my $drange = $search_value;
	my $lastdate;
	my $firstdate;
	if( $drange =~ s/-($REGEXP_DATETIME)$/-/o )
	{	
		$lastdate = $1;
	}
	if( $drange =~ s/^($REGEXP_DATETIME)(-?)$/$2/o )
	{
		$firstdate = $1;
	}

	if( !defined $firstdate && !defined $lastdate )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}

	# not a range.
	if( $drange ne "-" )
	{
		return EPrints::Search::Condition->new( 
				'=',
				$dataset,
				$self,
				$firstdate );
	}		

	my @r = ();

	if( defined $firstdate )
	{
		push @r, EPrints::Search::Condition->new( 
				'>=',
				$dataset,
				$self,
				$firstdate);
	}

	if( defined $lastdate )
	{
		push @r, EPrints::Search::Condition->new( 
				'<=',
				$dataset,
				$self,
				$lastdate);
	}

	if( scalar @r == 0 )
	{
		return EPrints::Search::Condition->new( 'FALSE' );
	}
	if( scalar @r == 1 ) { return $r[0]; }

	return EPrints::Search::Condition->new( "AND", @r );
	# error if @r is empty?
}

sub get_search_group { return 'date'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "day";
	$defaults{render_res} = "day";
	$defaults{render_style} = "long";
	$defaults{text_index} = 0;
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

sub render_xml_schema_type
{
	my( $self, $handle ) = @_;

	my $type = $handle->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $handle->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	my $pattern = $handle->make_element( "xs:pattern", value => "([0-9]{4}-[0-9]{2}-[0-9]{2})|([0-9]{4}-[0-9]{2})|([0-9]{4})" );
	$restriction->appendChild( $pattern );

	return $type;
}

######################################################################
1;
