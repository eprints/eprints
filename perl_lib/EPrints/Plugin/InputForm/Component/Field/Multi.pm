package EPrints::Plugin::InputForm::Component::Field::Multi;

use EPrints::Plugin::InputForm::Component::Field;

@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Multi";
	$self->{visible} = "all";

	return $self;
}

sub update_from_form
{
	my( $self, $processor ) = @_;

	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my $value = $field->form_value( $self->{session}, $self->{dataobj}, $self->{prefix} );
		$self->{dataobj}->set_value( $field->{name}, $value );
	}

	return;
}

sub validate
{
	my( $self ) = @_;

	my @problems;
	
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my $for_archive = 0;
		
		if( $field->{required} eq "for_archive" )
		{
			$for_archive = 1;
		}

		# cjg bug - not handling for_archive here.
		if( $field->{required} && !$self->{dataobj}->is_set( $field->{name} ) )
		{
			my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:".$field->{name} );
			$fieldname->appendChild( $field->render_name( $self->{session} ) );
			my $problem = $self->{session}->html_phrase(
				"lib/eprint:not_done_field" ,
				fieldname=>$fieldname );
			push @problems, $problem;
		}
		
		push @problems, $self->{dataobj}->validate_field( $field->{name} );
	}
	
	$self->{problems} = \@problems;
	
	return @problems;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;
	
	$self->{config}->{fields} = [];
	$self->{config}->{title} = $self->{session}->make_doc_fragment;

	foreach my $node ( $config_dom->getChildNodes )
	{
		if( $node->nodeName eq "field" ) 
		{
			my $field = $self->xml_to_metafield( $node );
			push @{$self->{config}->{fields}}, $field;
		}

		if( $node->nodeName eq "title" ) 
		{
			$self->{config}->{title} = EPrints::XML::contents_of( $node );
		}

		if( $node->nodeName eq "help" ) 
		{
			my $phrase_ref = $node->getAttribute( "ref" );
			$self->{config}->{help} = $self->{session}->make_element( "div", class=>"ep_sr_help_chunk" );
			if( EPrints::Utils::is_set( $phrase_ref ) )
			{
				$self->{config}->{help}->appendChild( $self->{session}->html_phrase( $phrase_ref ) );
			}
			else
			{
				$self->{config}->{help} = EPrints::XML::contents_of( $node );
			}
		}
	}
	
	if( @{$self->{config}->{fields}} == 0 )
	{
		EPrints::abort( "Multifield with no fields defined. Config was:\n".EPrints::XML::to_string( $config_dom ) );
	}
}

sub has_help
{
	my( $self ) = @_;

	return defined $self->{config}->{help};
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $table = $self->{session}->make_element( "table", class => "ep_multi" );
	my $tbody = $self->{session}->make_element( "tbody" );
	$table->appendChild( $tbody );
	my $first = 1;
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my %parts;
		$parts{class} = "";
		$parts{class} = "ep_first" if $first;
		$first = 0;

		$parts{label} = $field->render_name( $self->{session} );

		if( $field->{required} ) # moj: Handle for_archive
		{
			$parts{label} = $self->{session}->html_phrase( 
				"sys:ep_form_required",
				label=>$parts{label} );
		}
 
		$parts{help} = $field->render_help( $self->{session} );


		# Get the field and its value/default
		my $value;
		if( $self->{dataobj} )
		{
			$value = $self->{dataobj}->get_value( $field->{name} );
		}
		else
		{
			$value = $self->{default};
		}
		$parts{field} = $field->render_input_field( 
			$self->{session}, 
			$value, 
			undef,
			0,
			undef,
			$self->{dataobj},
			$self->{prefix},
			
		  );

		$parts{help_prefix} = $self->{prefix}."_help_".$field->get_name;

		$table->appendChild( $self->{session}->render_row_with_help( %parts ) );
	}
	return $table;
}


sub render_help
{
	my( $self, $surround ) = @_;
	return $self->{config}->{help};
}

sub render_title
{
	my( $self, $surround ) = @_;

	# nb. That this must clone the title as the title may be used 
	# more than once.
	return $self->{session}->clone_for_me( $self->{config}->{title}, 1 );
}


sub could_collapse
{
	my( $self ) = @_;

	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my $set = $self->{dataobj}->is_set( $field->{name} );
		return 0 if( $set );
	}
	
	return 1;
}

sub get_fields_handled
{
	my( $self ) = @_;

	my @names = ();
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		push @names, $field->{name};
	}
	return @names;
}

sub get_state_params
{
	my( $self ) = @_;

	my $params = "";
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		$params.= $field->get_state_params( $self->{session}, $self->{prefix}."_".$field->get_name );
	}
	return $params;
}

=pod
1;





