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

Can store a time value upto seconds granularity. The time must be in UTC because this field can not store the time zone part.

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

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{min_resolution} = "second";
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

