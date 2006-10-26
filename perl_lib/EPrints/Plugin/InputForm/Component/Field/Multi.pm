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

#	else
#	{
#		# no <help> configured. Do something sensible.
#		
#		$self->{config}->{help} = $self->{session}->make_doc_fragment;
#		foreach my $field ( @{$self->{config}->{fields}} )
#		{
#			my $chunk = $self->{session}->make_element( "div", class=>"ep_sr_help_chunk" );
#			my $strong = $self->{session}->make_element( "strong" );
#			$strong->appendChild( $field->render_name( $self->{session} ) );
#			$strong->appendChild( $self->{session}->make_text( ": " ) );
#			$chunk->appendChild( $strong );
#			$chunk->appendChild( 
#				$field->render_help( 
#					$self->{session}, 
#					$field->get_type() ) );
#			$self->{config}->{help}->appendChild( $chunk );
#		}
#	}

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
	my ($th, $tr, $td);
	my $first = 1;
	foreach my $field ( @{$self->{config}->{fields}} )
	{
		my $class = "";
		$class = "ep_first" if $first;
		$first = 0;

		$tr = $self->{session}->make_element( "tr", class=>$class );
		$table->appendChild( $tr );
		
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
		$th = $self->{session}->make_element( "th", class=>"ep_multi_heading" );

		my $label = $field->render_name( $self->{session} );

		if( $field->{required} eq "yes" ) # moj: Handle for_archive
		{
			$label = $self->{session}->html_phrase( 
				"sys:ep_form_required",
				label=>$label );
		}
	
		$th->appendChild( $label );
		$th->appendChild( $self->{session}->make_text( ":" ) );
 
		my $help_prefix = $self->{prefix}."_help_".$field->get_name;
		$td = $self->{session}->make_element( "td", class=>"ep_multi_input" );

		my $help_dom = $field->render_help(
			$self->{session},
			$field->get_type() );
	
		my $field_has_help = 1;
		$field_has_help = 0 if( EPrints::XML::is_empty( $help_dom ) );

		if( $field_has_help ) 
		{
			my $inline_help = $self->{session}->make_element( "div", id=>$help_prefix, class=>"ep_no_js ep_multi_inline_help" );
			my $inline_help_inner = $self->{session}->make_element( "div", id=>$help_prefix."_inner" );
			$inline_help->appendChild( $inline_help_inner );
			$inline_help_inner->appendChild( $help_dom );
			$td->appendChild( $inline_help );
		}

		$td->appendChild( $field->render_input_field( 
			$self->{session}, 
			$value, 
			undef,
			0,
			undef,
			$self->{dataobj},
			$self->{prefix},
			
		  ) );
		$tr->appendChild( $th );
		$tr->appendChild( $td );


		if( $field_has_help )
		{
			# help toggle

			my $td2 = $self->{session}->make_element( "td", class=>"ep_multi_help ep_only_js ep_toggle" );
			my $show_help = $self->{session}->make_element( "div", class=>"ep_sr_show_help ep_only_js", id=>$help_prefix."_show" );
			my $helplink = $self->{session}->make_element( "a", onClick => "EPJS_toggleSlide('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
			$show_help->appendChild( $self->html_phrase( "show_help",link=>$helplink ) );
			$td2->appendChild( $show_help );
		
			my $hide_help = $self->{session}->make_element( "div", class=>"ep_sr_hide_help ep_hide", id=>$help_prefix."_hide" );
			my $helplink2 = $self->{session}->make_element( "a", onClick => "EPJS_toggleSlide('$help_prefix',false,'block');EPJS_toggle('${help_prefix}_hide',false,'block');EPJS_toggle('${help_prefix}_show',true,'block');return false", href=>"#" );
			$hide_help->appendChild( $self->html_phrase( "hide_help",link=>$helplink2 ) );
			$td2->appendChild( $hide_help );
			$tr->appendChild( $td2 );
		}

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

1;





