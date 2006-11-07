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
			# Pull out the type
			my $type = $stage_node->getAttribute( "type" );
			$type = "Field" if( !EPrints::Utils::is_set( $type ) );

			my $surround = $stage_node->getAttribute( "surround" );
			$surround = "Default" if( !EPrints::Utils::is_set( $surround ) );

			my $collapse_attr = $stage_node->getAttribute( "collapse" );
			my $collapse = 1 if( defined $collapse_attr && $collapse_attr eq "yes" );

			my $surround_obj = $self->{session}->plugin( "InputForm::Surround::$surround" );
			if( !defined $surround_obj )
			{
				$surround_obj = $self->{session}->plugin( "InputForm::Surround::Default" ); 
			}

			my %params = (
					session=>$self->{session}, 
					xml_config=>$stage_node, 
					dataobj=>$self->{item}, 
					collapse=>$collapse,
					workflow=>$self->{workflow}, 
					surround=>$surround_obj );

			# Grab any values inside
			my $class = $EPrints::Plugin::REGISTRY->{"InputForm::Component::$type"};
			if( !defined $class )
			{
				print STDERR "Using placeholder for $type\n";
				$class = $EPrints::Plugin::REGISTRY->{"InputForm::Component::PlaceHolder"};
				$params{placeholding}=$type;
			}
			if( defined $class )
			{
				my $plugin = $class->new( %params );
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
		$div->appendChild( $component->{surround}->render( $component, $session ) );
		$dom->appendChild( $div );
	}

#  $form->appendChild( $session->render_action_buttons( %$submit_buttons ) ); 
  
	return $dom;
}


1;
