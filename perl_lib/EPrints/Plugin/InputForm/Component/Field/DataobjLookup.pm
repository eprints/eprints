package EPrints::Plugin::InputForm::Component::Field::DataobjLookup;

use EPrints::Plugin::InputForm::Component::Field;
@ISA = ( "EPrints::Plugin::InputForm::Component::Field" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );
	
	$self->{name} = "Dataobj Lookup";
	$self->{visible} = "all";

	# can be over-ridden in workflow: attribute modal="..." - references a InputForm::Component::Modal plug-in
	$self->{modal} ||= 'ItemSearch';

	return $self;
}

sub parse_config
{
        my( $self, $config_dom ) = @_;
	
	$self->SUPER::parse_config( $config_dom );

	if( defined $self->{config}->{field} && !$self->{config}->{field}->isa( "EPrints::MetaField::Dataobjref" ) )
	{
                push @{$self->{problems}}, $self->html_phrase( 'need_dataobjref',
                        xml => $self->{repository}->xml->create_text_node( $self->{repository}->xml->to_string( $config_dom ) )
                );
		return;
	}

#        <epp:phrase id="Plugin/InputForm/Component/Field:error_missing_field">Field component is missing field element in <pre><epc:pin name="xml"/></pre></epp:phrase>
#        <epp:phrase id="Plugin/InputForm/Component:error_missing_field_ref">Missing <em>ref</em> attribute in <pre><epc:pin name="xml" /></pre></epp:phrase>

	my @fields = $config_dom->getElementsByTagName( 'field' );
	if( scalar( @fields ) )
	{
		if( EPrints::Utils::is_set( $fields[0]->getAttribute( 'modal') ) )
		{
			$self->{modal} = $fields[0]->getAttribute( 'modal' );
		}
	}
}

sub update_from_form
{
	my( $self, $processor ) = @_;
	
	my $field = $self->{config}->{field};
	my $session = $self->{session};

        if( $session->internal_button_pressed )
        {
                my $internal = $self->get_internal_button;
		
		my $return_to = URI->new( $self->{session}->current_url( host => 1 ) );
		$return_to->query_form(
				$processor->screen->hidden_bits
		);

		# internal action triggered within the modal - need to forward the action to the appropriate Modal plugin - also see $self->export
		if( defined $session->param( 'modal' ) && $session->param( 'modal' ) )
		{
			my $plugin = $self->get_modal() or return;

			if( $plugin->param( 'ajax' ) && $self->wishes_to_export )
			{
				$self->set_note( "action", $plugin );
				$self->set_note( "return_to", $return_to );
			}
			return;
		}
		
		# internal action to the main component
		if( $internal =~ /^remove_(\d+)$/ )
		{
			my $dataobj = $self->{workflow}->{item};

			# multiple field?
			if( $field->property( 'multiple' ) )
			{
				my $values = $dataobj->value( $field->name );
				my @new_values;
				foreach(@$values)
				{
					next if( $_->{id} == $1 );
					push @new_values, $_;
				}
				$dataobj->set_value( $field->name, \@new_values );
			}
			else
			{
				my $value = $dataobj->value( $field->name );
				if( $value->{id} == $1 )
				{
					$dataobj->set_value( $field->name, undef );
				}
			}
		}
		elsif( $internal =~ /^(up|down)_(\d+)$/ && $field->property( 'multiple' ) )
		{
			my @values = @{$self->{workflow}->{item}->value( $field->name )||[]};

			if( $1 eq 'up' && $2 > 1 && scalar( @values ) )
			{
				@values[$2-1, $2-2] = @values[$2-2, $2-1];
			}
			elsif( $1 eq 'down' && $2 < scalar( @values ) )
			{
				@values[$2-1, $2] = @values[ $2, $2-1 ];
			}
			else
			{
				return;
			}
			
			$self->{workflow}->{item}->set_value( $field->name, \@values );
		}
		elsif( $internal eq 'show_modal' )
		{
			my $plugin = $self->get_modal() or return;

			if( $plugin->param( 'ajax' ) && $self->wishes_to_export )
			{
				$self->set_note( "action", $plugin );
				$self->set_note( "return_to", $return_to );
				return;
			}

		}
	}

	return;
}

sub get_modal
{
	my( $self ) = @_;
	        
	return undef unless( defined $self->{session} );

	my $params = {
		prefix => $self->{prefix},
		config => $self->{config},
		workflow => $self->{workflow},
	};
	
	my $modal_id = 'InputForm::Component::Modal::'.$self->{modal};
	return $self->{session}->plugin( $modal_id, %$params );
}

sub export_mimetype
{
        my( $self ) = @_;

	if( defined $self->{session}->param( 'modal' ) && $self->{session}->param( 'modal' ) )
	{
		my $modal = $self->get_modal();
		return $modal->export_mimetype if defined $modal;
	}

        my $plugin = $self->note( "action" );
        if( defined($plugin) && $plugin->param( "ajax" ) eq "automatic" )
        {
                return $plugin->export_mimetype;
        }

        return $self->SUPER::export_mimetype();
}

sub export
{
	my( $self ) = @_;

	my $frag;

	# used when the modal box is opened - this will call Modal::render() i.e. the content of the modal box       
	if( defined(my $plugin = $self->note( "action" )) )
	{
		# showing the modal 
		$frag = $plugin->render;

	}
	# used to forward an action to the Modal box
	elsif( defined $self->{session}->param( 'modal' ) )
	{
		# execute an internal action to the modal
		my $modal = $self->get_modal or return;
		$modal->from;
		$modal->export;
		return;
	}
	else
	{
		# refreshes the component
		$frag = $self->render_content;
	}
	
	print $self->{session}->xhtml->to_xhtml( $frag );
	$self->{session}->xml->dispose( $frag );
}

sub render_content
{
	my( $self, $surround ) = @_;

	my $session = $self->{session};
	my $field = $self->{config}->{field};
	my $dataobj = $self->{workflow}->{item};

	my $frag = $session->make_doc_fragment;

	if( $field->property( 'multiple' ) )
	{
		my $ol = $frag->appendChild( $session->make_element( 'ol', class => 'ep_component_item_list' ) );

		my $i = 1;
		my $n = scalar( @{ $dataobj->value( $field->name ) || [] } );

		# render current values (citation, perhaps method already exist in Meta/Dataobjref) + "Remove"  button
		foreach my $value ( @{ $dataobj->value( $field->name ) || [] } )
		{
			next unless( EPrints::Utils::is_set( $value ) );
			my $li = $ol->appendChild( $session->make_element( 'li' ) );
			$li->appendChild( $self->render_row( $field, $value, $dataobj, $i++, $n ) );
		}
	}
	elsif( $dataobj->is_set( $field->name ) )
	{
		my $value = $dataobj->value( $field->name );

		$frag->appendChild( $self->render_row( $field, $value, $dataobj ) );
	}

	my $link_phrase_id = !$field->property( 'multiple' ) && $self->{workflow}->{item}->is_set( $field->name ) ? 'change' : 'add';

	$frag->appendChild( $self->get_modal()->render_modal_link( value => $session->phrase( "lib/submissionform:action_$link_phrase_id"  ) ));

        $frag->appendChild( $self->{session}->make_javascript( <<EOJ ) );
	new Component_Field ('$self->{prefix}');
EOJ

	return $frag;

}

sub render_row
{
	my( $self, $field, $value, $dataobj, $i, $n ) = @_;

	my $session = $self->{session};
	my $imagesurl = $session->config( "rel_path" )."/style/images";
	
	my $frag = $session->make_doc_fragment;
	
	my $right = $frag->appendChild( $session->make_element( 'div', 
		class => 'ep_component_item_actions'
	) );

	if( defined $i )
	{
		if( $i < $n )
		{
			$right->appendChild( $session->make_element( 'input',
				type => 'image',
				alt => 'down',
				title => 'move down',
				src => "$imagesurl/multi_down.png",
				name=>"_internal_".$self->{prefix}."_down_".$i,
				class => "epjs_ajax epjs_ajax_button",
				value=>"1" 
			) );
		}
		else
		{
			$right->appendChild( $session->make_element( 'a', class => 'epjs_ajax_padding', href => '#' ) );
		}


		if( $i > 1 && $n > 1 )
		{
			$right->appendChild( $session->make_element( 'input',
				type => 'image',
				alt => 'up',
				title => 'move up',
				src => "$imagesurl/multi_up.png",
				name=>"_internal_".$self->{prefix}."_up_".$i,
				class => "epjs_ajax epjs_ajax_button",
				value=>"1" 
			) );
		}
		elsif( $i == 1 )
		{
			$right->appendChild( $session->make_element( 'a', class => 'epjs_ajax_padding', href => '#' ) );
		}
	}
	
	$right->appendChild( $session->make_element( 'input', 
                                title => $session->phrase( 'lib/submissionform:action_deselect' ), 
                                name => '_internal_'.$self->{prefix}.'_remove_'.$value->{id}, 
                                type => 'image', 
                                class => 'epjs_ajax epjs_ajax_button',
				value => '1',
				src => "$imagesurl/delete.png",
	) );

	my $left = $frag->appendChild( $session->make_element( 'div', 
		class => 'ep_component_item_desc'
	) );

	$left->appendChild( $field->render_value_no_multiple( $session, $value, 0, 0, $dataobj ) );

	$frag->appendChild( $session->make_element( 'div', 
		class => 'ep_component_item_separator' 
	) );

	return $frag;
}

1;
