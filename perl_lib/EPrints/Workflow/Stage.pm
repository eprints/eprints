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
	$self->_read_components( $stage->getChildNodes );

	return $self;
}

	

sub _read_components
{
	my( $self, @stage_nodes ) = @_;

	$self->{components} = [];
	foreach my $stage_node ( @stage_nodes )
	{
		my $name = $stage_node->nodeName;
		if( $name eq "component" )
		{

			# Nb. Cyclic refs on stage & workflow. May mess up g.c.
			my %params = (
					session=>$self->{session}, 
					xml_config=>$stage_node, 
					dataobj=>$self->{item}, 
					stage=>$self, 	
					workflow=>$self->{workflow},
					processor=>$self->{workflow}->{processor} ); 

			# Pull out the type

			my $type = $stage_node->getAttribute( "type" );
			$type = "Field" if( !EPrints::Utils::is_set( $type ) );

			my $surround = $stage_node->getAttribute( "surround" );
			$params{surround} = $surround if( EPrints::Utils::is_set( $surround ) );
			
			my $collapse_attr = $stage_node->getAttribute( "collapse" );
			$params{collapse} = 1 if( defined $collapse_attr && $collapse_attr eq "yes" );

			my $help_attr = $stage_node->getAttribute( "show_help" );
			$help_attr ||= "toggle";
			if( $help_attr eq "never" )
			{
				$params{no_help} = 1;
			}
			elsif( $help_attr eq "always" )
			{
				$params{no_toggle} = 1;
			}

			my $id = $stage_node->getAttribute( "id" );
			if( !defined $id )
			{
				EPrints::abort( "ID did not get set in component" );
			}
			$params{prefix} = $id;
			
			my $pluginid = "InputForm::Component::$type";
			
			my $plugin = $self->{session}->plugin( $pluginid, %params );
			if( !defined $plugin )
			{
				$plugin = $self->{session}->plugin( "InputForm::Component::Error",
					%params,
					problems => [$self->{session}->html_phrase( "Plugin/InputForm/Component:error_invalid_component",
						placeholding => $self->{session}->xml->create_text_node( $type ),
						xml => $self->{session}->xml->create_text_node( $self->{session}->xml->to_string( $params{xml_config} ) ),
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

			if ($self->{workflow}->{processor}->{required_fields_only}) {
				if ($plugin->is_required()) {
					push @{$self->{components}}, $plugin;
				}
			} else {
				push @{$self->{components}}, $plugin;
			}
		}
		elsif( $name eq "title" )
		{
			$self->{title} = $stage_node->getFirstChild->nodeValue;
		}
		elsif( $name eq "short-title" )
		{
			$self->{short_title} = $stage_node->getFirstChild->nodeValue;
		}
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
		if($self->{repository}->get_lang->has_phrase( $dataset->base_id.":workflow:stage:".$self->get_name.":title" )){
			return $self->{repository}->html_phrase( $dataset->base_id.":workflow:stage:".$self->get_name.":title" );
		}else{
			return $self->{repository}->html_phrase( "metapage_title_".$self->get_name );
		}
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
		$div->appendChild( $component->get_surround()->render( $component, $session ) );
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

