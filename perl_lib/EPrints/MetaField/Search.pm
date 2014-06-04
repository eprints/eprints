######################################################################
#
# EPrints::MetaField::Search;
#
######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<EPrints::MetaField::Search> - no description

=head1 DESCRIPTION

not done

=over 4

=cut

# datasetid

package EPrints::MetaField::Search;

use strict;
use warnings;

BEGIN
{
	our( @ISA );

	@ISA = qw( EPrints::MetaField::Longtext );
}

use EPrints::MetaField::Longtext;

######################################################################
# 
# $searchexp = $field->make_searchexp( $repository, $value, [$basename] )
#
# This method should only be called on fields of type "search". 
# Return a search expression from the serialised expression in value.
# $basename is passed to the Search to prefix all HTML form
# field ids when more than one search will exist in the same form. 
#
######################################################################

sub make_searchexp
{
	my( $self, $repository, $value, $basename ) = @_;

	my $dataset = $repository->dataset( $self->{datasetid} );

	my $searchexp = EPrints::Search->new(
		repository => $repository,
		dataset => $dataset,
		prefix => $basename );

	# new-style search spec
	if( defined $value && $value =~ /^\?/ )
	{
		my $url = URI->new( $value );
		my %spec = $url->query_form;
		$searchexp = $repository->plugin( "Search::$spec{plugin}",
			dataset => $dataset,
			prefix => $basename,
		);
		if( !defined $searchexp )
		{
			$repository->log( "Unknown search plugin in: $value" );
			return;
		}
		$value = $spec{exp};
	}

	my $fields;
	my $conf_key = $self->get_property( "fieldnames_config" );
	if( defined($conf_key) )
	{
		$fields = $repository->config( $conf_key );
	}
	else
	{
		$fields = $self->get_property( "fieldnames" );
	}

	$fields = [] if !defined $fields;

	foreach my $fieldname (@$fields)
	{
		if( !$dataset->has_field( $fieldname ) )
		{
			$repository->log( "Field specified in search field configuration $conf_key does not exist in dataset ".$dataset->confid.": $fieldname" );
			next;
		}
		$searchexp->add_field(
			fields => [$dataset->get_field( $fieldname )],
		);
	}

	if( defined $value )
	{
		if( scalar @$fields )
		{
			$searchexp->from_string( $value );
		}
		else
		{
			$searchexp->from_string_raw( $value );
		}
	}

	return $searchexp;
}		

sub get_search_group { return 'search'; } 

sub get_property_defaults
{
	my( $self ) = @_;
	my %defaults = $self->SUPER::get_property_defaults;
	$defaults{datasetid} = $EPrints::MetaField::REQUIRED;
	$defaults{fieldnames} = $EPrints::MetaField::UNDEF;
	$defaults{fieldnames_config} = $EPrints::MetaField::UNDEF;
	return %defaults;
}


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

