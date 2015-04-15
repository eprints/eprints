######################################################################
#
# EPrints::MetaField::Multilang;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Multilang> - Subclass of compound for multilingual data.

=head1 DESCRIPTION

not done

=over 4

=cut

package EPrints::MetaField::Multilang;

use strict;
use warnings;

BEGIN
{
	our( @ISA );
	
	@ISA = qw( EPrints::MetaField::Compound );
}

use EPrints::MetaField::Compound;

sub extra_subfields
{
	my( $self ) = @_;

	return (
		{ sub_name=>"lang", type=>"namedset", set_name => "languages", input_style => "short", maxlength => 16, },
	);
}

sub get_search_conditions_not_ex
{
	my( $self, $session, $dataset, $search_value, $match, $merge,
		$search_mode ) = @_;
	
	my $field = $self->property( "fields_cache" )->[0];

	return $field->get_search_conditions_not_ex( 
		$session, $dataset,$search_value,$match,$merge,$search_mode );
}

=item $value = $field->lang_value( $langid, $value )

Returns the most local language value for $langid.

If $langid is undefined uses the current language.

=cut

sub lang_value
{
	my( $self, $langid, $value ) = @_;

	$langid = $self->{repository}->get_langid if !defined $langid;

	return $self->{repository}->best_language( $langid, %{
		$self->value_to_langhash( $value )
	});
}

sub render_value
{
	my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

	if( $alllangs )
	{
		return $self->SUPER::render_value( 
				$session,$value,$alllangs,$nolink,$object);
	}

	my $f = $self->get_property( "fields_cache" );

	$value = $self->lang_value( undef, $value )
		if $self->property( "multiple" );

    	# always render the 1st sub_field's sub_name. Override this render_value if you need something different to be rendered. 
	$value = $value->{$f->[0]->property( "sub_name" )};
	return $f->[0]->render_single_value( $session, $value );
}

sub value_to_langhash
{
	my( $self, $value ) = @_;

	no warnings; # suppress undef lang
	return { map {
		$_->{lang} => $_
	} @$value };
}

sub ordervalue
{
	my( $self, $value, $session, $langid, $dataset ) = @_;

	# custom or only one value which we don't do anything special with
	if( defined $self->{make_value_orderkey} || !$self->property( "multiple" ) )
	{
		return $self->SUPER::ordervalue( $value, $session, $langid, $dataset );
	}

	$value = $self->lang_value( $langid, $value );

	return $session->get_database->quote_ordervalue($self, $self->ordervalue_single( $value, $session, $langid, $dataset ));
}

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{input_ordered} = 0;
	$defaults{input_boxes} = 1;
	$defaults{match} = "IN";
	return %defaults;
}

######################################################################

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

