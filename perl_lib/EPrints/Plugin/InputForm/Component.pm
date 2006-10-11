
######################################################################
#
# EPrints::Plugin::InputForm::Component
#
######################################################################
#
#  This file is part of GNU EPrints 2.
#  
#  Copyright (c) 2000-2004 University of Southampton, UK. SO17 1BJ.
#  
#  EPrints 2 is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  EPrints 2 is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with EPrints 2; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
######################################################################

=pod

=head1 NAME

B<EPrints::Plugin::InputForm::Component> - A single form component 

=cut

package EPrints::Plugin::InputForm::Component;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::InputForm::Component::ABSTRACT = 1;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Base component plugin: This should have been subclassed";
	$self->{visible} = "all";
	# don't have a config when we first load this to register it as a plugin class
	if( defined $opts{xml_config} )
	{
		$self->{session} = $opts{session};
		$self->{collapse} = $opts{collapse};
		$self->{prefix} = "id".$self->{session}->get_next_id;
		$self->{dataobj} = $opts{dataobj};
		$self->{dataset} = $opts{dataobj}->get_dataset;
		$self->parse_config( $opts{xml_config} );
	}
	$self->{problems} = [];	

	return $self;
}

=pod

=item $bool = $component->parse_config( $config_dom )

Parses the supplied DOM object and populates $component->{config}

=cut

sub parse_config
{
	my( $self, $config_dom ) = @_;
}

=pod

=item $bool = $component->is_required()

returns true if this component is required to be completed before the
workflow may proceed

=cut

sub is_required
{
	my( $self ) = @_;
	return 0;
}

=pod

=item $bool = $component->is_collapsed()

returns true if this component is to be rendered in a compact form
(for example, just title / required / help).

=cut

sub is_collapsed
{
	my( $self ) = @_;

	return 0 if( !$self->{collapse} );

	my $r =  $self->could_collapse;
	
	return $r;
}

# return false if this component does not want to be collapsed, even if
# the config requested it.
sub could_collapse
{
	my( $self ) = @_;

	return 1;
}

sub update_from_form
{
	return ();
}

sub validate
{
	return ();
}


# Useful parameter methods


# Returns all parameters for this component as a hash,
# with the prefix removed.

sub params
{
	my( $self ) = @_;
	my $prefix = $self->{prefix}."_";
	my %params = ();

	foreach my $p ( $self->{session}->param() )
	{
		if( $p =~ /^$prefix(.+)$/ )
		{
			$params{$1} = $self->{session}->param( $p );
		}
	}
	return %params;
}

sub param
{
	my( $self, $param ) = @_;

	my $fullname = $self->{prefix}."_".$param;
	
	return $self->{session}->param( $fullname );
}

sub get_internal_button
{
	my( $self ) = @_;

	my $internal_button = $self->{session}->get_internal_button;

	return undef unless defined $internal_button;

	my $prefix = $self->{prefix}."_";
	return undef unless $internal_button =~ s/^$prefix//;

	return $internal_button;
}

sub get_problems
{
	my( $self ) = @_;
	return $self->{problems};
}

=pod

=item $help = $component->render_help( $surround )

Returns DOM containing the help text for this component.

=cut

sub render_help
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "help" );
}

=pod

=item $name = $component->get_name()

Returns the unique name of this field (for prefixes, etc).

=cut

sub get_name
{
	my( $self ) = @_;
}

=pod

=item $title = $component->render_title( $surround )

Returns the title of this component as a DOM object.

=cut

sub render_title
{
	my( $self, $surround ) = @_;
	return $self->html_phrase( "title" );
}

=pod

=item $content = $component->render_content( $surround )

Returns the DOM for the content of this component.

=cut

sub render_content
{
	my( $self, $surround ) = @_;
}


=pod

=item @field_ids = $component->get_fields_handled

Returns an array of the names of the metadata fields which this
field handles. Used for jumps.

=cut

sub get_fields_handled
{
	my( $self ) = @_;

	return ();
}


# $metafield = $self->xml_to_metafield( $xml, [$dataset] )
#
# Take an XML configuration of a field in a component and return a metafield.
# tweak the metafield to make it required if needed.
#
# If dataset is not defined then use the dataset of the current item.

sub xml_to_metafield
{
	my( $self, $xml, $dataset ) = @_;

	if( !defined $dataset )
	{
		$dataset = $self->{dataset};
	}

	# Do a few validation checks.
	if( $xml->getNodeName ne "field" )
	{
		EPrints::abort(
			"xml_to_metafield config error: Not a field node" );
	}
	my $ref = $xml->getAttribute( "ref" );	
	if( !EPrints::Utils::is_set( $ref ) )
	{
		EPrints::abort(
			"xml_to_metafield config error: No field ref attribute" );
	}

	my $field = $dataset->get_field( $ref );
	
	if( !defined $field )
	{
		EPrints::abort(
			"xml_to_metafield config error: Invalid field ref attribute($ref)" );
	}

	my $cloned = 0;

	foreach my $prop ( qw/ required input_lookup_url / )
	{
		my $setting = $xml->getAttribute( $prop );

		if( EPrints::Utils::is_set( $setting ) )
		{
			if( !$cloned )
			{
				$field = $field->clone;
				$cloned = 1;
			}	
			$field->set_property( $prop, $setting );
		}
	}

	return $field;
}

######################################################################
1;
