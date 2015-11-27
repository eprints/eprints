=for Pod2Wiki

=head1 NAME

EPrints::MetaField::Time - date + time

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

=head1 PROPERTIES

In addition to those properties available in L<EPrints::MetaField::Date> and L<EPrints::MetaField>:

=head2 render_res

Reduce the resolution the date is shown as.

=over 4

=item B<"second">

=item "minute"

=item "hour"

=back

=head1 METHODS

=over 4

=cut


package EPrints::MetaField::Time;

use EPrints::MetaField::Date;

@ISA = qw( EPrints::MetaField::Date );

use strict;

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_style} = "long";
	$defaults{render_res} = "second";
	$defaults{maxlength} = 19;
	$defaults{regexp} = qr/\d\d\d\d(?:-\d\d(?:-\d\d(?:[ T]\d\d(?::\d\d(?::\d\dZ?)?)?)?)?)?/;
	$defaults{parts} = [qw( year month day hour minute second )];
	return %defaults;
}

sub should_reverse_order { return 1; }

sub get_basic_input_elements_short
{
	my( $self, $session, $value, $basename, $staff, $obj ) = @_;

	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $session->xhtml->input_field( $basename, substr($value,0,10),
		type => "text",
		class => "ep_form_text",
		noenter => 1,
		size => 10,
		maxlength => 10,
	) );
	$frag->appendChild( $session->xhtml->input_field( $basename . "_time", substr($value,11),
		type => "text",
		class => "ep_form_text",
		noenter => 1,
		size => 8,
		maxlength => 8,
	) );
	
	return [ [ { el=>$frag } ] ];
}

sub render_hour_input
{
	my( $self, $basename, $value ) = @_;

	my $repo = $self->{repository};

	my @values = map { sprintf("%02d", $_) } 0..23;
	my %labels = map {
			$_ => $_,
		} @values;
	unshift @values, "";
	$labels{""} = "?";

	return $repo->render_option_list(
		name => "${basename}_hour",
		id => "${basename}_hour",
		values => \@values,
		default => $value,
		labels => \%labels );
}

sub render_minute_input
{
	my( $self, $basename, $value ) = @_;

	my $repo = $self->{repository};

	my @values = map { sprintf("%02d", $_) } 0..59;
	my %labels = map {
			$_ => $_,
		} @values;
	unshift @values, "";
	$labels{""} = "?";

	return $repo->render_option_list(
		name => "${basename}_minute",
		id => "${basename}_minute",
		values => \@values,
		default => $value,
		labels => \%labels );
}

sub render_second_input
{
	my( $self, $basename, $value ) = @_;

	my $repo = $self->{repository};

	my @values = map { sprintf("%02d", $_) } 0..59;
	my %labels = map {
			$_ => $_,
		} @values;
	unshift @values, "";
	$labels{""} = "?";

	return $repo->render_option_list(
		name => "${basename}_minute",
		id => "${basename}_minute",
		values => \@values,
		default => $value,
		labels => \%labels );
}

sub form_value_basic
{
	my( $self, $session, $basename ) = @_;
	
	my $value = $self->SUPER::form_value_basic( $session, $basename );

	if( $self->{input_style} eq "short" )
	{
		my $time = $session->param( "$basename\_time" );
		if(
			EPrints::Utils::is_set( $value ) && length($value) == 10 &&
			EPrints::Utils::is_set( $time )
		  )
		{
			$value = $self->_build_value( "$value $time" );
		}
	}

	return $value;
}

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

=back

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

