######################################################################
#
# EPrints::MetaField::Time;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Time> - no description

=head1 DESCRIPTION

Can store a time value up to seconds granularity. The time must be in UTC because this field can not store the time zone part.

The value is set and returned as a string formatted as:

	YYYY-MM-DD hh:mm:ss

Where:

	YYYY - year
	MM - month (01-12)
	DD - day (01-31)
	hh - hours (00-23)
	mm - minutes (00-59)
	ss - seconds (00-59)

Note: if you set the time using ISO datetime format (YYYY-MM-DDThh:mm:ssZ) it will automatically be converted into the native format.

=head1 METHODS

=over 4

=cut


package EPrints::MetaField::Time;

use EPrints::MetaField::Date;
@ISA = qw( EPrints::MetaField::Date );

use strict;

sub get_sql_names
{
	my( $self ) = @_;

	return map { $self->get_name() . "_" . $_ } qw( year month day hour minute second );
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
	$value .= sprintf(" %02d",$parts[3]) if( defined $parts[3] );
	$value .= sprintf(":%02d",$parts[4]) if( defined $parts[4] );
	$value .= sprintf(":%02d",$parts[5]) if( defined $parts[5] );

	return $value;
}

sub value_from_sql_row
{
	my( $self, $session, $row ) = @_;

	my @parts = grep { defined $_ } splice(@$row,0,6);

	return undef if !@parts;

	return $self->_build_value( join(' ', @parts) );
}

sub sql_row_from_value
{
	my( $self, $session, $value ) = @_;

	my @parts;
	@parts = split /[-: TZ]/, $value if defined $value;
	@parts = @parts[0..5];

	return @parts;
}

sub render_single_value
{
	my( $self, $session, $value ) = @_;

	my $res = $self->{render_res};

	my $l = 19;
	if( $res eq "minute" ) { $l = 16; }
	if( $res eq "hour" ) { $l = 13; }
	if( $res eq "day" ) { $l = 10; }
	if( $res eq "month" ) { $l = 7; }
	if( $res eq "year" ) { $l = 4; }
		
	if( defined $value )
	{
		$value = substr( $value, 0, $l );
	}

	if( $self->{render_style} eq "short" )
	{
		return EPrints::Time::render_short_date( $session, $value );
	}
	return EPrints::Time::render_date( $session, $value );
}
	

sub get_basic_input_ids
{
	my( $self, $session, $basename, $staff, $obj ) = @_;

	return( $basename."_second", $basename."_minute", $basename."_hour",
		$basename."_day", $basename."_month", $basename."_year" );
}

sub get_basic_input_elements
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my $frag = $session->make_doc_fragment;
		
	my $min_res = $self->get_property( "min_resolution" );
	
	my $div;

	if( defined $min_res && $min_res ne "second" )
	{	
		$div = $session->make_element( "div", class=>"ep_form_field_help" );	
		$div->appendChild( $session->html_phrase( 
			"lib/metafield:date_res_".$min_res ) );
		$frag->appendChild( $div );
	}

	$div = $session->make_element( "div" );
	my( $hour,$minute,$second,$year, $month, $day ) = ("", "", "","","","");
	if( defined $value && $value ne "" )
	{
		($year, $month, $day, $hour,$minute,$second) = split /[-: TZ]/, $value;
		$month = "00" if( !defined $month || $month == 0 );
		$day = "00" if( !defined $day || $day == 0 );
		$year = "" if( !defined $year || $year == 0 );
		$hour = "" if( !defined $hour );
		$minute = "" if( !defined $minute );
		$second = "" if( !defined $second );
	}
 	my $dayid = $basename."_day";
 	my $monthid = $basename."_month";
 	my $yearid = $basename."_year";
 	my $hourid = $basename."_hour";
 	my $minuteid = $basename."_minute";
 	my $secondid = $basename."_second";

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:year" ) );
	$div->appendChild( $session->make_text(" ") );

	$div->appendChild( $session->render_noenter_input_field(
		class => "ep_form_text",
		name => $yearid,
		id => $yearid,
		value => $year,
		size => 4,
		maxlength => 4 ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:month" ) );
	$div->appendChild( $session->make_text(" ") );
	$div->appendChild( $session->render_option_list(
		name => $monthid,
		id => $monthid,
		values => \@EPrints::MetaField::Date::MONTHKEYS,
		default => $month,
		labels => $self->_month_names( $session ) ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:day" ) );
	$div->appendChild( $session->make_text(" ") );

	my @daykeys = ();
	my %daylabels = ();
	for( 0..31 )
	{
		my $key = sprintf( "%02d", $_ );
		push @daykeys, $key;
		$daylabels{$key} = ($_==0?"?":$key);
	}
	$div->appendChild( $session->render_option_list(
		name => $dayid,
		id => $dayid,
		values => \@daykeys,
		default => $day,
		labels => \%daylabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:hour" ) );
	$div->appendChild( $session->make_text(" ") );

	my @hourkeys = ( "" );
	my %hourlabels = ( ""=>"?" );
	for( 0..23 )
	{
		my $key = sprintf( "%02d", $_ );
		push @hourkeys, $key;
		$hourlabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $hourid,
		id => $hourid,
		values => \@hourkeys,
		default => $hour,
		labels => \%hourlabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:minute" ) );
	$div->appendChild( $session->make_text(" ") );

	my @minutekeys = ( "" );
	my %minutelabels = ( ""=>"?" );
	for( 0..59 )
	{
		my $key = sprintf( "%02d", $_ );
		push @minutekeys, $key;
		$minutelabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $minuteid,
		id => $minuteid,
		values => \@minutekeys,
		default => $minute,
		labels => \%minutelabels ) );

	##############################################
	$div->appendChild( $session->make_text(" ") );
	##############################################

	$div->appendChild( 
		$session->html_phrase( "lib/metafield:second" ) );
	$div->appendChild( $session->make_text(" ") );

	my @secondkeys = ( "" );
	my %secondlabels = ( ""=>"?" );
	for( 0..59 )
	{
		my $key = sprintf( "%02d", $_ );
		push @secondkeys, $key;
		$secondlabels{$key} = $key;
	}
	$div->appendChild( $session->render_option_list(
		name => $secondid,
		id => $secondid,
		values => \@secondkeys,
		default => $second,
		labels => \%secondlabels ) );

	##############################################
	##############################################




	$frag->appendChild( $div );
	
	return [ [ { el=>$frag } ] ];
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;

	my @parts;
	for(qw( year month day hour minute second ))
	{
		my $part = $session->param( $basename."_$_" );
		last if !EPrints::Utils::is_set( $part ) || ($part == 0 && ( $_ eq "year" || $_ eq "month" || $_ eq "day" ));
		push @parts, $part;
	}

	return undef if !@parts;

	return $self->_build_value( join(' ', @parts) );
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

	my $l = 19;
	if( $res eq "minute" ) { $l = 16; }
	if( $res eq "hour" ) { $l = 13; }
	if( $res eq "day" ) { $l = 10; }
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

sub get_value_label
{
	my( $self, $session, $value ) = @_;

	return EPrints::Time::render_date( $session, $value );
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "second";
	$defaults{render_res} = "second";
	$defaults{regexp} = qr/\d\d\d\d(?:-\d\d(?:-\d\d(?:[ T]\d\d(?::\d\d(?::\d\dZ?)?)?)?)?)?/;
	return %defaults;
}

sub should_reverse_order { return 1; }

sub render_xml_schema_type
{
	my( $self, $session ) = @_;

	my $type = $session->make_element( "xs:simpleType", name => $self->get_xml_schema_type );

	my $restriction = $session->make_element( "xs:restriction", base => "xs:string" );
	$type->appendChild( $restriction );
	my $pattern = $session->make_element( "xs:pattern", value => "([0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}Z{0,1})|([0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2})|([0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2})|([0-9]{4}-[0-9]{2}-[0-9]{2})|([0-9]{4}-[0-9]{2})|([0-9]{4})" );
	$restriction->appendChild( $pattern );

	return $type;
}

=item $datetime = $time->iso_value( $value )

Returns $value in ISO datetime format (YYYY-MM-DDThh:mm:ssZ).

Returns undef if the value is unset.

=cut

sub iso_value
{
	my( $self, $value ) = @_;

	return undef if !EPrints::Utils::is_set( $value );

	return join('T',split / /, $self->_build_value( $value )) . "Z";
}

=back

=head1 SEE ALSO

L<EPrints::MetaField::Date>.

=cut

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

