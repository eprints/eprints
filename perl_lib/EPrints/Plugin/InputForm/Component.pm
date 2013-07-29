=for Pod2Wiki

=head1 NAME

B<EPrints::Plugin::InputForm::Component> - A single form component 

=head1 DESCRIPTION

A component is an HTML widget for use in a L<EPrints::Workflow::Stage>. A L<EPrints::Plugin::InputForm::Component::Field> component renders the form inputs for a L<EPrints::MetaField> but component subclasses can be used to provide any required behaviour around user input. Components don't even have to be form inputs e.g. just render a fragment of XHTML.

Where components are shown and configuration are controlled through the EPrints XML workflow. The workflow reads the component type, loads the referenced plugin and passes the XML node to L</parse_config>:

=for verbatim_lang xml

	<component type="Upload" show_help="always" />

In this instance the L<EPrints::Plugin::InputForm::Component::Upload> component is being inserted into the workflow and its help is being set to always be shown.

Components share many of the features seen in L<EPrints::Plugin::Screen>s. The L</update_from_form> method is called from the Screen's L</from> stage and the component L</render>s a fragment of XHTML that is inserted into the resulting page. Components have no equivalent to L<EPrints::Plugin::Screen/can_be_viewed> - it is assumed that the workflow only exposes inputs to which the user has access.

A component will be created twice during a workflow response: to process the incoming data (L</update_from_form>) and to generate the new page (L</render>). Therefore you can not rely on data persisting between the update and rendering stages, unless you store the data in the L<EPrints::ScreenProcessor>.

Buttons in components are classed as "internal actions". Internal actions do not normally change the response workflow but only how the component renders. This is used to provide search features, provide more button inputs etc.

=head2 AJAX Support

Some components support AJAX-like incremental updates. The Javascript Component class can make requests aimed at a Component by specifying the C<component=cXX> CGI parameter and it is then up to the component what it renders.

The default behaviour is to render the XHTML fragment represented by the component, which is used by Javascript as an in-place replacement. Elsewhere a JSON response is used to drive client-side behaviour.

Similarly to L<EPrints::Plugin::Screen>, AJAX components have a life-cycle of:

=over 4

=item 1. update_from_form() reads form values and sets them on the object

=item 2. wishes_to_export() determines if this component is exporting

=item 3. export() generates a response

=back

See also L<EPrints::Plugin::InputForm::Component::Documents>, which uses a JSON response to determine the documents to update.

=head1 METHODS

=over 4

=cut

package EPrints::Plugin::InputForm::Component;

use strict;

our @ISA = qw/ EPrints::Plugin /;

$EPrints::Plugin::InputForm::Component::DISABLE = 1;

=item $component = EPrints::Plugin::InputForm::Component->new( %opts )

Create a new component object with following parameters:

	session - session object
	collapse - whether the component starts collapsed
	no_help - hide field help
	no_toggle - hide help toggle button
	surround - surround class, defaults to 'Default'
	prefix - prefix for the component id
	dataobj - object the field is being rendered for

See also L<EPrints::Plugin::InputForm::Surround::Default>.

=cut

sub new
{
	my( $class, %opts ) = @_;

	$opts{problems} = [] if !exists $opts{problems};
	$opts{name} = "Base component plugin: This should have been subclassed" if !exists $opts{name};
	$opts{visible} = "all" if !exists $opts{visible};

	my $self = $class->SUPER::new( %opts );

	if( defined &Scalar::Util::weaken )
	{
		Scalar::Util::weaken($self->{workflow});
		Scalar::Util::weaken($self->{processor});
	}

	# don't have a config when we first load this to register it as a plugin class
	if( defined $opts{xml_config} )
	{
		$self->parse_config( $opts{xml_config} );
	}

	return $self;
}

sub set_note
{
	my( $self, $name, $value ) = @_;

	$self->{processor}->{notes}->{$self->{prefix}}->{$name} = $value;
}

sub note
{
	my( $self, $name ) = @_;

	return $self->{processor}->{notes}->{$self->{prefix}}->{$name};
}

=pod

=item $bool = $component->parse_config( $config_dom )

Parses the supplied DOM object and populates $component configuration.

=cut

sub parse_config
{
	my( $self, $xml_config ) = @_;

	foreach my $attr ($xml_config->attributes)
	{
		my $value = $attr->nodeValue;
		next if !EPrints::Utils::is_set( $value );
		my $name = $attr->nodeName;

		if( $name eq "id" )
		{
			$self->{prefix} = $value;
		}
		elsif( $name eq "surround" )
		{
			$self->{surround} = $value;
		}
		elsif( $name eq "collapse" )
		{
			$self->{collapse} = 1 if $value eq "yes";
		}
		elsif( $name eq "help" )
		{
			$self->{no_help} = 1 if $value eq "never";
			$self->{no_toggle} = 1 if $value eq "always";
			# toggle
		}
	}

	return 1;
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

	return "" unless defined $internal_button;

	my $prefix = $self->{prefix}."_";
	return "" unless $internal_button =~ s/^$prefix//;

	return $internal_button;
}

sub problems
{
	my( $self ) = @_;

	return @{$self->{problems}};
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

=item $bool = $component->wishes_to_export

See L<EPrints::Plugin::Screen/wishes_to_export>.

=cut

sub wishes_to_export
{
	shift->EPrints::Plugin::Screen::wishes_to_export( @_ );
}

=item $mime_type = $component->export_mimetype

See L<EPrints::Plugin::Screen/export_mimetype>.

=cut

sub export_mimetype
{
	my( $self ) = @_;

	binmode(STDOUT, ":utf8");

	return "text/html; charset=UTF-8";
}

=item $component->export

See L<EPrints::Plugin::Screen/export>.

=cut

sub export
{
	shift->EPrints::Plugin::Screen::export( @_ );
}

=item $xhtml = $component->render

Renders the component in its surround.

=cut

sub render
{
	my( $self ) = @_;

	return $self->get_surround->render( $self, $self->{session} );
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

	return $self->{repository}->xml->create_document_fragment;
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

	my $repo = $self->{repository};

	if( !defined $dataset )
	{
		$dataset = $self->{dataset};
	}

	my $ref = $xml->getAttribute( "ref" );	
	if( !EPrints::Utils::is_set( $ref ) )
	{
		# xml_to_metafield config error: No field ref attribute
		push @{$self->{problems}}, $repo->html_phrase( "Plugin/InputForm/Component:error_missing_field_ref",
			xml => $repo->xml->create_text_node( $repo->xml->to_string( $xml ) ),
		);
		return;
	}

	my $field = $dataset->get_field( $ref );
	
	if( !defined $field )
	{
		# xml_to_metafield config error: Invalid field ref attribute($ref)
		push @{$self->{problems}}, $repo->html_phrase( "Plugin/InputForm/Component:error_invalid_field_ref",
			ref => $repo->xml->create_text_node( $ref ),
			xml => $repo->xml->create_text_node( $repo->xml->to_string( $xml ) ),
		);
		return;
	}

	my %props;

	# e.g. required input_lookup_url input_lookup_params top options
	# input_boxes input_add_boxes input_ordered
	foreach my $attr ($xml->attributes)
	{
		my $value = $attr->nodeValue;
		next if !EPrints::Utils::is_set( $value );
		my $name = $attr->nodeName;
		if( $name eq "required" )
		{
			$value = $value eq "yes";
		}
		elsif( $name eq "options" )
		{
			$value = [split ',', $value];
		}
		$props{$name} = $value;
	}
	foreach my $child ( $xml->childNodes )
	{
		my $name = $child->nodeName;
		if( $name eq "help" )
		{
			$props{help_xhtml} = EPrints::XML::contents_of( $child );
		}
		elsif( $name eq "title" )
		{
			$props{title_xhtml} = EPrints::XML::contents_of( $child );
		}
		elsif( $name eq "sub_field" )
		{
			if( !$field->isa( "EPrints::MetaField::Compound" ) )
			{
				push @{$self->{problems}}, $self->{repository}->xml->create_text_node(
					"xml_to_metafield config error: can only create a nested field definition for Compound fields (".$field->name." is not of type compound)"
				);
				return;
			}
			my $c = $child->cloneNode( 1 );
			$c->setName( "field" );
			my $sub_name = $c->getAttribute( "ref" );
			$c->setAttribute( "ref", $field->name . "_" . $sub_name );
			my $sub_field = $self->xml_to_metafield( $c, $dataset );
			return if !defined $sub_field;
			$sub_field = $sub_field->clone;
			$props{$sub_field} = $sub_field;
			EPrints::XML::dispose( $c );
		}
	}

	return $field if !%props;

	$field = $field->clone;
	while(my( $name, $value ) = each %props)
	{
		if( UNIVERSAL::isa( $value, "EPrints::MetaField" ) )
		{
			foreach my $f (@{$field->property( "fields_cache" )})
			{
				$f = $value, last if $f->name eq $value->name;
			}
		}
		elsif( $field->has_property( $name ) )
		{
			$field->set_property( $name, $value );
		}
		# should maybe warn here?
	}

	return $field;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	return "";
}

sub get_state_fragment
{
	my( $self, $processor ) = @_;

	return "";
}

=back

=cut

######################################################################
1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2013 University of Southampton.

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

