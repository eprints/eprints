package EPrints::Plugin::InputForm::Component::Field::Multi;

use EPrints::Plugin::InputForm::Component::Field;

@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use Unicode::String qw(latin1);

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
	my( $self ) = @_;

	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my $value = $field->form_value( $self->{session}, $self->{dataobj}, $self->{prefix} );
		$self->{dataobj}->set_value( $field->{name}, $value );
	}

	return ();
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
		if( $field->{required} eq "yes" && !$self->{dataobj}->is_set( $field->{name} ) )
		{
			my $fieldname = $self->{session}->make_element( "span", class=>"ep_problem_field:".$field->{name} );
			$fieldname->appendChild( $field->render_name( $self->{session} ) );
			my $problem = $self->{session}->html_phrase(
				"lib/eprint:not_done_field" ,
				fieldname=>$fieldname );
			push @problems, $problem;
		}
		
		push @problems, $self->{session}->get_repository->call(
			"validate_field",
			$field,
			$self->{dataobj}->get_value( $field->{name} ),
			$self->{session},
			$for_archive );
	}
	
	$self->{problems} = \@problems;
	
	return @problems;
}

sub parse_config
{
	my( $self, $config_dom ) = @_;
	
	$self->{config}->{fields} = [];

# moj: We need some default phrases for when these aren't specified.
#	$self->{config}->{title} = ""; 
#	$self->{config}->{help} = ""; 

	my @fields = $config_dom->getElementsByTagName( "field" );
	my @title_nodes = $config_dom->getElementsByTagName( "title" );
	my @help_nodes  = $config_dom->getElementsByTagName( "help" );

	if( @fields == 0 )
	{
		# error!
		EPrints::abort( "Multifield with no fields defined. Config was:\n".EPrints::XML::to_string( $config_dom ) );
	}

	foreach my $field_tag ( @fields )
	{
		my $field = $self->xml_to_metafield( $field_tag );
		push @{$self->{config}->{fields}}, $field;
	}


	$self->{config}->{title} = $self->{session}->make_doc_fragment;
	if( scalar @title_nodes == 1 )
	{
		foreach my $kid ( $title_nodes[0]->getChildNodes )
		{
			$self->{config}->{title}->appendChild( $kid );
		}	
	}

	
	if( scalar @help_nodes == 1 )
	{
		my $phrase_ref = $help_nodes[0]->getAttribute( "ref" );
		$self->{config}->{help} = $self->{session}->make_element( "div", class=>"ep_sr_help_chunk" );
		if( EPrints::Utils::is_set( $phrase_ref ) )
		{
			$self->{config}->{help}->appendChild( $self->{session}->html_phrase( $phrase_ref ) );
		}
		else
		{
			my @phrase_dom = $help_nodes[0]->getElementsByTagName( "phrase" );
			if( scalar @phrase_dom >= 1 )
			{
				$self->{config}->{help}->appendChild( $phrase_dom[0] );
			}
		}
	}
	else
	{
		# no <help> configured. Do something sensible.
		
		$self->{config}->{help} = $self->{session}->make_doc_fragment;
		foreach my $field ( @{$self->{config}->{fields}} )
		{
			my $chunk = $self->{session}->make_element( "div", class=>"ep_sr_help_chunk" );
			my $strong = $self->{session}->make_element( "strong" );
			$strong->appendChild( $field->render_name( $self->{session} ) );
			$strong->appendChild( $self->{session}->make_text( ": " ) );
			$chunk->appendChild( $strong );
			$chunk->appendChild( 
				$field->render_help( 
					$self->{session}, 
					$field->get_type() ) );
			$self->{config}->{help}->appendChild( $chunk );
		}
	}

}

sub render_content
{
	my( $self, $surround ) = @_;

	my $table = $self->{session}->make_element( "table" );
	my $tbody = $self->{session}->make_element( "tbody", class => "sidetable" );
	$table->appendChild( $tbody );
	my ($th, $tr, $td);
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		$tr = $self->{session}->make_element( "tr" );
		
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
		
		# Append field
		$th = $self->{session}->make_element( "th" );

		my $label = $field->render_name( $self->{session} );

		if( $field->{required} eq "yes" ) # moj: Handle for_archive
		{
			$label = $self->{session}->html_phrase( 
				"sys:ep_form_required",
				label=>$label );
		}
		
		$th->appendChild( $label );
 
		$td = $self->{session}->make_element( "td" );
		$td->appendChild( $field->render_input_field( 
			$self->{session}, 
			$value, 
			undef,
			undef,
			0,
			undef,
			$self->{dataobj},
			$self->{prefix},
			
		  ) );
		$tr->appendChild( $th );
		$tr->appendChild( $td );
		$tbody->appendChild( $tr );
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
	return $self->{config}->{title};
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

1;





