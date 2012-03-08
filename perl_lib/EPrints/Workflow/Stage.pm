=head1 NAME

EPrints::Workflow::Stage

=cut

package EPrints::Workflow::Stage;

use strict;

sub new
{
	my( $class, $stage, $workflow ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{workflow} = $workflow;
	$self->{session} = $workflow->{session};
	$self->{item} = $workflow->{item};
	$self->{repository} = $self->{session}->get_repository;

	$self->{name} = $stage->getAttribute("name");
	unless( EPrints::Utils::is_set( $self->{name} ) )
	{
		EPrints::abort( "Workflow stage with no name attribute." );
	}
	$self->{action_buttons} = $stage->getAttribute( "action_buttons" );
	if( !$self->{action_buttons} )
	{
		$self->{action_buttons} = "both";
	}
	elsif( $self->{action_buttons} !~ /^(top|bottom|both|none)$/ )
	{
		$self->{session}->get_repository->log( "Warning! Workflow <stage> action_buttons attribute expected one of 'top', 'bottom' or 'both' but instead got '$self->{action_buttons}'" );
		$self->{action_buttons} = "both";
	}

	# Creating a new stage
	$self->_parse_stage( $stage );

	return $self;
}

sub _parse_stage
{
	my( $self, $stage ) = @_;

	$self->{components} = [];
	foreach my $node ($stage->childNodes)
	{
		my $name = $node->localName;
		if( $name eq "component" )
		{
			$self->_parse_component( $node );
		}
		elsif( $name eq "title" )
		{
			$self->{title} = $self->{session}->xml->text_contents_of( $node );
		}
		elsif( $name eq "short-title" )
		{
			$self->{short_title} = $self->{session}->xml->text_contents_of( $node );
		}
	}
}

sub _parse_component
{
	my( $self, $xml_config ) = @_;

	# Nb. Cyclic refs on stage & workflow. May mess up g.c.
	my %params = (
			xml_config=>$xml_config, 
			dataobj=>$self->{item}, 
			dataset=>$self->{item}->get_dataset,
			stage=>$self, 	
			workflow=>$self->{workflow},
			processor=>$self->{workflow}->{processor} ); 

	# Pull out the type

	my $type = $xml_config->getAttribute( "type" );
	$type = "Field" if( !EPrints::Utils::is_set( $type ) );

	my $plugin = $self->{session}->plugin( "InputForm::Component::$type", %params );
	if( !defined $plugin )
	{
		$plugin = $self->{session}->plugin( "InputForm::Component::Error",
			%params,
			problems => [$self->{session}->html_phrase( "Plugin/InputForm/Component:error_invalid_component",
				placeholding => $self->{session}->xml->create_text_node( $type ),
				xml => $self->{session}->xml->create_text_node( $self->{session}->xml->to_string( $xml_config ) ),
			)],
		);
	}
	elsif( $plugin->problems )
	{
		$plugin = $self->{session}->plugin( "InputForm::Component::Error",
			%params,
			problems => [$plugin->problems],
		);
	}
	elsif( !defined $plugin->{prefix} )
	{
		EPrints::abort( "Prefix did not get set in component $type (id=?): did you call SUPER::parse_config() in Component?" );
	}

	if ($self->{workflow}->{processor}->{required_fields_only})
	{
		if ($plugin->is_required())
		{
			push @{$self->{components}}, $plugin;
		}
	}
	else
	{
		push @{$self->{components}}, $plugin;
	}
}

=item $flag = $stage->action_buttons()

Returns the action buttons setting: both, top, bottom or none.

=cut

sub action_buttons
{
	my( $self ) = @_;

	return $self->{action_buttons};
}

sub get_name
{
	my( $self ) = @_;
	return $self->{name};
}

sub get_title
{
	my( $self ) = @_;
	return $self->{title};
}

sub render_title
{
	my( $self ) = @_;

	my $title = $self->get_title;
	if( !defined $title )
	{
		my $dataset = $self->{item}->dataset;
		return $self->{repository}->html_phrase( $dataset->id.":workflow:stage:".$self->get_name.":title" );
	}

	return $self->{repository}->xml->create_text_node( $title );
}

sub get_short_title
{
	my( $self ) = @_;
	return $self->{short_title};
}

sub get_components
{
	my( $self ) = @_;
	return @{$self->{components}};
}

sub get_fields_handled
{
	my( $self ) = @_;

	my @list = ();
	foreach my $component ( $self->get_components )
	{
		push @list, $component->get_fields_handled;
	}
	return @list;
}

# return an array of problems
sub validate
{
	my( $self ) = @_;
	
	my @problems = ();
	foreach my $component (@{$self->{components}})
	{
		push @problems, $component->validate();
	}
	return @problems;
}

# return an array of problems
sub update_from_form
{
	my( $self , $processor ) = @_;

	foreach my $component (@{$self->{components}})
	{
		$component->update_from_form($processor);
	}
	
	$self->{item}->commit;
}

sub get_state_params
{
	my( $self, $processor ) = @_;

	my $params = "";
	my $fragment = "";

	foreach my $component (@{$self->{components}})
	{
		$params .= $component->get_state_params( $processor );
		$fragment = $component->get_state_fragment( $processor )
			if !$fragment;
	}

	return $fragment ? "$params#$fragment" : $params;
}

sub render
{
	my( $self, $session, $workflow ) = @_;

	my $dom = $session->make_doc_fragment();

	foreach my $component (@{$self->{components}})
	{
		my $div;
		my $surround;
		
		$div = $session->make_element(
			"div",
			class => "ep_form_field_input" );
		$div->appendChild( $component->render );
		$dom->appendChild( $div );
	}

#  $form->appendChild( $session->render_action_buttons( %$submit_buttons ) ); 
  
	return $dom;
}


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

