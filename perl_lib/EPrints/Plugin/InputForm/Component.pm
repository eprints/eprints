
######################################################################
#
# EPrints::Plugin::InputForm::Component
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

B<EPrints::Plugin::InputForm::Component> - A single form component 

=cut

package EPrints::Plugin::InputForm::Component;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::InputForm::Component::DISABLE = 1;

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
		$self->{surround} = $opts{surround};
		$self->{prefix} = $opts{prefix};
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

=item $surround = $component->get_surround()

returns the surround for this component.

=cut

sub get_surround
{
	my( $self ) = @_;

	my $surround = "Default";	
	
	if( EPrints::Utils::is_set( $self->{surround} ) )
	{
		$surround = $self->{surround};
	}
		
	my $surround_obj = $self->{session}->plugin( "InputForm::Surround::$surround" );
	
	if( !defined $surround_obj )
	{
		$surround_obj = $self->{session}->plugin( "InputForm::Surround::Default" ); 
	}

	return $surround_obj; 
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

sub get_internal_value
{
	my( $self ) = @_;

	my $prefix = $self->{prefix}."_";
	foreach my $param ( $self->{session}->param )
	{
		next unless( $param =~ s/^(_internal|passon)_$prefix// );
		my $v = $self->{session}->param( $param );
		next unless EPrints::Utils::is_set( $v );
		return $v;
	}
	return undef;
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

=item $boolean = $component->has_help()

Returns true if this component has help available.

=cut

sub has_help
{
	my( $self ) = @_;
	return 0;
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
	if( $xml->nodeName ne "field" )
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
	foreach my $prop ( qw/ required input_lookup_url input_lookup_params top options / )
	{
		my $setting = $xml->getAttribute( $prop );
		next unless EPrints::Utils::is_set( $setting );

		if( $prop eq "required" && $setting eq "yes" ) { $setting = 1; }
		if( $prop eq "required" && $setting eq "no" ) { $setting = 0; }
		if( $prop eq "options" ) { $setting = [split( ",", $setting )]; }
		
		if( !$cloned ) { $field = $field->clone; $cloned = 1; }	
		$field->set_property( $prop, $setting );
	}
	foreach my $child ( $xml->getChildNodes )
	{
		if( $child->nodeName eq "help" )
		{
			if( !$cloned ) { $field = $field->clone; $cloned = 1; }	
			$field->set_property( 
				"help_xhtml", 
				EPrints::XML::contents_of( $child ) );
		}
		if( $child->nodeName eq "title" )
		{
			if( !$cloned ) { $field = $field->clone; $cloned = 1; }	
			$field->set_property( 
				"title_xhtml", 
				EPrints::XML::contents_of( $child ) );
		}
	}
	return $field;
}

sub get_state_params
{
	my( $self ) = @_;

	return "";
}

######################################################################
1;
