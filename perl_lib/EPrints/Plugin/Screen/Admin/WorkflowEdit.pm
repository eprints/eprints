package EPrints::Plugin::Screen::Admin::WorkflowEdit::ConditionElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{exp_attrs} = {
		"test" => [1],
	};
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::AttributeElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{name} = "";
	$self->{value} = "";
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement;

use strict;

sub new
{
	my( $class ) = @_;
	my $self = {};

	$self->{exp_contents} = {
		"FlowElement" => [1, "*"],
		"StageElement" => [1, "*"],
	};
	$self->{contents} = [];
	$self->{tag} = "workflow";	
	$self->{exp_attrs} = {};
	$self->{attrs} = [];

	$self->{counters} = {};
	$self->{conditions} = [];

	bless $self, $class;
	return $self;
}

sub render
{
	my( $self, $session ) = @_;

	my $out = $session->make_element( "div" );#, style => "margin: 1pt; border: solid black 1px" ); 
	
	$out->appendChild( $session->make_text( $self->{tag} ) );	
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $test = $condition->get_attribute( "test" );
		my $cond = $session->make_element( "div", class => "we_conditional" );
		$cond->appendChild( $session->make_text( "Condition: ".$test ) );
		$out->appendChild( $cond );
	}
	
	my $contents = $self->{contents};
	foreach my $content ( @$contents )
	{
		$out->appendChild( $content->render( $session ) );	
	}
	return $out;	
}

sub tag_map
{
	my $tagmap =
	{
		"stage" => "StageElement",
		"component" => "ComponentElement",
		"flow" => "FlowElement",
		"field" => "FieldElement",
		"help" => "HelpElement",
		"title" => "TitleElement",
		"workflow" => "WorkflowElement",
	};

	return $tagmap; 
}

sub get_attribute
{
	my( $self, $name ) = @_;

	foreach my $attribute ( @{$self->{attrs}} )
	{
		if( $attribute->{name} eq $name )
		{
			return $attribute->{value};
		}
	}
	return undef;
}

sub to_dom
{
	my( $self, $session, $skip_children ) = @_;
	my $root = $session->make_doc_fragment;
	my $currnode = $root;
	
	$skip_children = 0 if( !defined $skip_children );
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $if = $session->make_element( "if" );
		foreach my $attribute ( @{$condition->{attrs}} )
		{
			if( $attribute->{name} eq "test" )
			{
				$if->setAttribute( "test", $attribute->{value} );
			}
			last;
		}
		$currnode->appendChild( $if );
		$currnode = $if;	
	}

	my $el = $session->make_element( $self->{tag} );

	foreach my $attr ( @{$self->{attrs}} )
	{
		$el->setAttribute( $attr->{name}, $attr->{value} );
	}

	if( !$skip_children )
	{
		foreach my $element ( @{$self->{contents}} )
		{
			$el->appendChild( $element->to_dom( $session ) );
		}
	}
	$currnode->appendChild( $el );
	return $root;
}

sub element_from_dom
{
	my( $dom ) = @_;
	
	my $condition;
	my $node = $dom;
	my $tagmap = EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::tag_map();
	if( $node->getNodeName() eq "if" )
	{
		$condition = EPrints::Plugin::Screen::Admin::WorkflowEdit::ConditionElement->new_from_dom( $node );
		my $children = $node->getChildNodes();
		my $ok = 0;
		for my $child( @$children )
		{
			my $name = $child->getNodeName();
			next unless( $tagmap->{$name} || $name eq "if" );
			$node = $child;
			$ok = 1;
			last;
		}
		return unless $ok;
	}
	my $name = $node->getNodeName();

	return undef if( !$tagmap->{$name} );
	my $element_class = "EPrints::Plugin::Screen::Admin::WorkflowEdit::".$tagmap->{$name};
	my $element = $element_class->new_from_dom( $node );

	$element->add_condition( $condition ) if defined $condition;
	return $element;
}

sub new_from_dom
{
	my( $class, $dom, $skip_children ) = @_;

	$skip_children = 0 if( !defined $skip_children );

	my $element = $class->new();
	
	foreach my $attr ( keys %{$element->{exp_attrs}} )
	{
		next unless $dom->hasAttribute( $attr );

		my $attrib = new EPrints::Plugin::Screen::Admin::WorkflowEdit::AttributeElement();
		$attrib->{name} = $attr;
		$attrib->{value} = $dom->getAttribute( $attr );
		$element->add_attribute( $attrib );				
	}	

	return $element if( $dom->getNodeName() eq "if" || $skip_children );
	my $tagmap = EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::tag_map();
	my $children = $dom->getChildNodes();
	foreach my $child ( @$children )
	{
		my $name = $child->getNodeName();
		next unless ( $tagmap->{$name} || $name eq "if" );

		$element->add_element( 
			EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::element_from_dom( $child ) 
		);
	}
	return $element;
}

sub add_condition
{
	my( $self, $condition ) = @_;
	push @{$self->{conditions}}, $condition; 
}

sub add_attribute
{
	my( $self, $attribute ) = @_;
	push @{$self->{attrs}}, $attribute; 
}

sub add_element
{
	my( $self, $element ) = @_;

	my $type = ref $element;
	$type =~ s/EPrints::Plugin::Screen::Admin::WorkflowEdit:://;
		
	if( $self->can_add( $type ) )
	{
		push @{$self->{contents}}, $element;
		if( !$self->{counters}->{$type} )
		{
			$self->{counters}->{$type} = 0;
		}
		$self->{counters}->{$type}++;
	}
	else
	{
		print STDERR "Can't add $type to $self\n";
	}
}

sub can_add
{
	my( $self, $type ) = @_;
	
	return 0 unless $self->can_contain( $type );
	if( !$self->{counters}->{$type} )
	{
		$self->{counters}->{$type} = 0;
	}

	my $count = $self->{counters}->{$type};
	my( $min, $max ) = @{$self->{exp_contents}->{$type}};
	$count++;
	return 0 if( $count > $max && $max ne "*" );
	return 1;
}

sub can_contain
{
	my( $self, $type ) = @_;
	return 1 if( $self->{exp_contents}->{$type} );
	return 0;
}

sub is_valid
{
	my( $self ) = @_;
	
	foreach my $type ( keys %{$self->{exp_contents}} )
	{
		my $count = $self->{counters}->{$type};	
		my( $min, $max ) = @{$self->{exp_contents}->{$type}};
		return 0 if( $count < $min );
		return 0 if( $count > $max && $max ne "*" );
		foreach my $content ( @{$self->{contents}} )
		{
			return 0 unless( $content->is_valid );
		}
	}
	return 1;
}


package EPrints::Plugin::Screen::Admin::WorkflowEdit::FlowElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{exp_contents} = {
		"StageElement" => [1, "*"],
	};
	
	$self->{tag} = "flow";
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::StageElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{exp_contents} = {
		"ComponentElement" => [0, "*"],
	};
	$self->{exp_attrs} = {
		"ref" => [1],
		"name" => [1],
	};

	$self->{tag} = "stage";
	return $self;
}

sub render
{
	my( $self, $session ) = @_;

	my $out = $session->make_element( "div", class => "we_stage" );
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $test = $condition->get_attribute( "test" );
		my $cond = $session->make_element( "div", class => "we_conditional" );
		$cond->appendChild( $session->make_text( "Condition: ".$test ) );
		$out->appendChild( $cond );
	}

	my $name = $self->get_attribute( "name" );
	my $ref = $self->get_attribute( "ref" );
	
	if( $name ) 
	{
		my $title_bar = $session->make_element( "div", class => "we_stage_bar" ); 
		my $title = $session->make_element( "div", class => "we_stage_title" );
		my $text = "Stage (".$self->get_attribute( "name" ).")";
		$title->appendChild( $session->make_text( $text ) );
		$title_bar->appendChild( $title );
		$out->appendChild( $title_bar );
	}
	elsif( $ref )
	{
		$out->appendChild( $session->make_text( "Stage Ref (".$self->get_attribute( "ref" ).")" ) );
	}

	my $contents = $self->{contents};
	foreach my $content ( @$contents )
	{
		$out->appendChild( $content->render( $session ) );	
	}
	return $out;	
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::ComponentElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{exp_contents} = {
		"TitleElement" => [0, "*"],
		"HelpElement" => [0, "*"],
		"FieldElement" => [0, "*"],
	};
	
	$self->{exp_attrs} = {
		"surround" => [1], 
		"collapse" => [1], 
		"type" => [1], 
	};

	$self->{tag} = "component";
	return $self;
}

sub render
{
	my( $self, $session ) = @_;

	my $out = $session->make_element( "div", class => "ep_sr_component" );
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $test = $condition->get_attribute( "test" );
		my $cond = $session->make_element( "div", class => "we_conditional" );
		$cond->appendChild( $session->make_text( "Condition: ".$test ) );
		$out->appendChild( $cond );
	}

	my $cont_div = $session->make_element( "div", class => "ep_sr_content" );	
	my $contents = $self->{contents};
	
	my $title_bar = $session->make_element( "div", class => "ep_sr_title_bar" ); 
	my $title = $session->make_element( "div", class => "ep_sr_title" );
	my $text = "Component (Default)";
	if( defined $self->get_attribute( "type" ) )
	{
		my $type = $self->get_attribute( "type" );
		$text = "Component (".$type.")";
	}

	$title->appendChild( $session->make_text( $text ) ); 
	$title_bar->appendChild( $title );
	$cont_div->appendChild( $title_bar );

	if( $self->get_attribute( "type" ) eq "XHTML" )
	{
		$cont_div->appendChild( $session->make_text( EPrints::XML::to_string( $self->{content} ) ) );
	}
	else
	{
		foreach my $content ( @$contents )
		{
			$cont_div->appendChild( $content->render( $session ) );	
		}
	}
	$out->appendChild( $cont_div );
	return $out;	
}

sub new_from_dom
{
	my( $class, $dom ) = @_;
	my $element;
	
	if( $dom->getAttribute("type") eq "XHTML" )
	{
		$element = EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::new_from_dom( $class, $dom, 1 );
		$element->{content} = EPrints::XML::contents_of($dom);
	}
	else
	{
		$element = EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::new_from_dom( $class, $dom, 0 );
	}
	return $element;
}

sub to_dom
{
	my( $self, $session ) = @_;
	my $element;

	if( $self->get_attribute( "type") eq "XHTML" )
	{
		$element = $self->SUPER::to_dom( $session, 1 );
		$element->getFirstChild()->appendChild( $self->{content} );
	}
	else
	{
		$element = $self->SUPER::to_dom( $session, 0 );
	}
	return $element;
}	

package EPrints::Plugin::Screen::Admin::WorkflowEdit::FieldElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );
	
sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	
	$self->{tag} = "field";
	$self->{exp_contents} = 
	{
		"HelpElement" => [0, "*"],
	};
	
	$self->{exp_attrs} = {
		"ref" => [1], 
		"input_lookup_url" => [1], 
		"input_lookup_params" => [1], 
		"options" => [1], 
		"required" => [1], 
	};

	return $self;
}

sub render
{
	my( $self, $session ) = @_;

	my $out = $session->make_element( "div", class => "we_field" ); 
	
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $test = $condition->get_attribute( "test" );
		my $cond = $session->make_element( "div", class => "we_conditional" );
		$cond->appendChild( $session->make_text( "Condition: ".$test ) );
		$out->appendChild( $cond );
	}
	
	$out->appendChild( $session->make_text( "Field: ".$self->get_attribute( "ref" ) ) );
	
	my $contents = $self->{contents};
	foreach my $content ( @$contents )
	{
		$out->appendChild( $content->render( $session ) );	
	}
	return $out;	
}


package EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{tag} = "";
	$self->{content} = "";
	return $self;
}

sub render
{
	my( $self, $session ) = @_;

	my $out = $session->make_element( "div", class => "we_title" );
	
	foreach my $condition ( @{$self->{conditions}} )
	{
		my $test = $condition->get_attribute( "test" );
		my $cond = $session->make_element( "div", class => "we_conditional" );
		$cond->appendChild( $session->make_text( "Condition: ".$test ) );
		$out->appendChild( $cond );
	}
	$out->appendChild( $self->{content} );
	return $out;	
}


sub new_from_dom
{
	my( $class, $dom ) = @_;
	my $element = $class->new();
	$element->{content} = EPrints::XML::contents_of($dom);
	return $element;
}

sub to_dom
{
	my( $self, $session ) = @_;
	my $element = $self->SUPER::to_dom( $session );
	$element->getFirstChild()->appendChild( $self->{content} );
	return $element;
}	


package EPrints::Plugin::Screen::Admin::WorkflowEdit::HelpElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{tag} = "help";
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::TitleElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{tag} = "title";
	return $self;
}


package EPrints::Plugin::Screen::Admin::WorkflowEdit;

use EPrints::Plugin::Screen;

our @ISA = ( 'EPrints::Plugin::Screen' );

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = undef;

	return $self;
}

sub render
{
	my( $self ) = @_;

	# Load workflow XML
	my $doc = EPrints::XML::parse_xml( $self->{session}->get_repository->get_conf( "config_path" )."/workflows/eprint/default.xml" );
	
	my $root = $doc->documentElement();

	my $session = $self->{session};
	my $user = $session->current_user;

	my $norm = $self->normalize( $root );

	my $struc = $self->to_structure( $norm ); 
	return $struc->render( $session );
}

sub normalize
{
	my( $self, $root ) = @_;
	my $out = $self->{session}->make_doc_fragment;

	my $normed = $self->normalize_element( $root );
	$self->flatten_ifs( $normed );

	return $normed;
}

sub flatten_ifs
{
	my( $self, $root ) = @_;
	return unless $root->hasChildNodes();
	my $children = $root->getChildNodes();
	foreach my $element ( @$children )
	{
		if( $element->getNodeName() eq "if" )
		{
			my $test = "(".$element->getAttribute( "test" ).")"; 
			if( $element->hasChildNodes )
			{
				my $children = $element->getChildNodes();

				if( $children->getLength() > 1 )
				{
					print STDERR "Tree not normalized\n";
					return;
				}

				if( $children->getLength() == 1 )
				{
					my $child = $children->item(0);
					if( $child->getNodeName() eq "if" )
					{
						while( $child->getNodeName() eq "if" )
						{
							$test .= " and (".$child->getAttribute( "test" ).")";
							$child = $child->getChildNodes()->item(0);
						}
						
						my $replace = $root->getOwnerDocument()->createElement( "if" );
						$replace->setAttribute( "test", $test );
						$replace->appendChild( $child );
						$self->flatten_ifs( $child );	
						$root->replaceChild( $replace, $element );
					}
				}
			}
		}
		else
		{
			$self->flatten_ifs( $element );
		}
	}
}

sub normalize_element
{
	my( $self, $element ) = @_;
	
	my $out = $self->{session}->make_doc_fragment;

	if( $element->getNodeName eq "#text" )
	{
		my $val = $element->getNodeValue();
		$val =~ s/\s+//g;
		return undef if( $val eq "" );
	}


	if( $element->getNodeName() eq "choose" )
	{
		return $self->normalize_choose( $element );	
	}

	if( $element->getNodeName() eq "if" )
	{
		# Flatten
		if( $element->hasChildNodes )
		{
			foreach my $child ( $element->getChildNodes() )
			{
				my $norm_child = $self->normalize_element( $child );
				if( $norm_child )
				{
					my $dup_el = EPrints::XML::clone_node( $element, 0 );
					$dup_el->appendChild( $norm_child ); 
					$out->appendChild( $dup_el );	
				}
			}
			return $out;
		}
	}

	my $dup_el = EPrints::XML::clone_node( $element, 0 ); 
	$out->appendChild( $dup_el );

	if( $element->hasChildNodes )
	{
		foreach my $child ( $element->getChildNodes() )
		{
			my $norm_child = $self->normalize_element( $child );
			if( $norm_child )
			{
				$dup_el->appendChild( $norm_child );
			}
		}
	}
	return $out;
}

sub to_structure
{
	my( $self, $root ) = @_;

	my $workflow = $root->getElementsByTagName( "workflow" );
	my $el = EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement::element_from_dom( $workflow->item(0) );

	return $el;
}

sub normalize_choose
{
	my( $self, $element ) = @_;

	my $out = $self->{session}->make_doc_fragment;
	my @prior_tests = ();
	foreach my $child ( $element->getChildNodes() )
	{
		if( $child->getNodeName() eq "when" )
		{
			my $test = $child->getAttribute( "test" );
			my $neg_test = "";
			if( scalar @prior_tests )
			{ 
				$neg_test = join( " and ", @prior_tests );
				$neg_test .= " and ";
			}
			foreach my $when_child ( $child->getChildNodes() )
			{
				my $norm_child = $self->normalize_element( $when_child );
				if( $norm_child )
				{
					my $if = $self->{session}->make_element( "if" );
					$if->setAttribute("test", $neg_test.$test );
					$if->appendChild( $norm_child );
					$out->appendChild( $if );
				}
			}
			push @prior_tests, "!(".$test.")";
		}
		elsif( $child->getNodeName() eq "otherwise" )
		{
			my $neg_test = "";
			if( scalar @prior_tests )
			{ 
				$neg_test = join( " and ", @prior_tests );
			}
			foreach my $when_child ( $child->getChildNodes() )
			{
				my $norm_child = $self->normalize_element( $when_child );
				if( $norm_child )
				{
					my $if = $self->{session}->make_element( "if" );
					$if->setAttribute("test", $neg_test );
					$if->appendChild( $norm_child );
					$out->appendChild( $if );
				}
			}
		}
	}
	return $out;
}	

sub is_normal
{
	my( $self, $root ) = @_;

	my $choose = $root->getElementsByTagName( "choose", 1 );
	return 0 if( $choose->getLength() > 0 );
	my $when = $root->getElementsByTagName( "when", 1 );
	return 0 if( $when->getLength() > 0 );
	my $otherwise = $root->getElementsByTagName( "otherwise", 1 );
	return 0 if( $otherwise->getLength() > 0 );
	
	my $ifs = $root->getElementsByTagName( "if", 1 );
	foreach my $if ( @$ifs )
	{
		my $children = $if->getChildNodes();
		return 0 if( $children->getLength() > 1 );
	}
	
	return 1;
}

1;
