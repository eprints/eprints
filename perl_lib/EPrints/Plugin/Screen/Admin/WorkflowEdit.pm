package EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement;

use strict;

sub new
{
	my( $class ) = @_;
	my $self = {};
	$self->{contains} = {};
	$self->{contents} = [];
	$self->{counters} = {};
	bless $self, $class;
	return $self;
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
	my( $min, $max ) = @{$self->{contains}->{$type}};
	$count++;
	return 0 if( $count > $max && $max != -1 );
	return 1;
}

sub can_contain
{
	my( $self, $type ) = @_;
	return 1 if( $self->{contains}->{$type} );
	return 0;
}

sub is_valid
{
	my( $self ) = @_;
	
	foreach my $type ( keys %{$self->{contains}} )
	{
		my $count = $self->{counters}->{$type};	
		my( $min, $max ) = @{$self->{contains}->{$type}};
		return 0 if( $count < $min );
		return 0 if( $count > $max && $max != -1 );
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
	$self->{contains} = {
		"StageElement" => [1, -1],
	};
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::StageElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{contains} = {
		"ComponentElement" => [1, -1],
	};
	return $self;
}


package EPrints::Plugin::Screen::Admin::WorkflowEdit::ComponentElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

sub new
{
	my( $class ) = @_;
	my $self = $class->SUPER::new();
	$self->{contains} = {
		"TitleElement" => [0, -1],
		"HelpElement" => [0, -1],
		"FieldElement" => [0, -1],
	};
	return $self;
}

package EPrints::Plugin::Screen::Admin::WorkflowEdit::FieldElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

package EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::WorkflowElement' );

package EPrints::Plugin::Screen::Admin::WorkflowEdit::HelpElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement' );

package EPrints::Plugin::Screen::Admin::WorkflowEdit::TitleElement;
our @ISA = ( 'EPrints::Plugin::Screen::Admin::WorkflowEdit::DataElement' );


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

	$self->normalize( $root );

	# Build a test structure

	my $flow = new EPrints::Plugin::Screen::Admin::WorkflowEdit::FlowElement();
	my $stage = new EPrints::Plugin::Screen::Admin::WorkflowEdit::StageElement();
	my $component = new EPrints::Plugin::Screen::Admin::WorkflowEdit::ComponentElement();
	my $field = new EPrints::Plugin::Screen::Admin::WorkflowEdit::FieldElement();

	$flow->add_element( $stage );
	$stage->add_element( $component );
	$component->add_element( $field );

	print STDERR $flow->is_valid()."\n";

	return $session->make_doc_fragment;
}

sub normalize
{
	my( $self, $root ) = @_;
	my $out = $self->{session}->make_doc_fragment;

	my $normed = $self->normalize_element( $root );

	EPrints::XML::tidy( $normed );
	print EPrints::XML::to_string( $normed );
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
