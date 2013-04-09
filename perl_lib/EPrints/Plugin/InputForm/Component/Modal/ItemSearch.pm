package EPrints::Plugin::InputForm::Component::Modal::ItemSearch;

our @ISA = ( 'EPrints::Plugin::InputForm::Component::Modal' );
use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{name} = "Modal - Item Search";

	return $self;
}

sub json
{
        my( $self ) = @_;
	
        my $json = {};
        
	my $action_id = $self->{processor}->{action};
        if( defined $action_id )
        {
                $json->{action} = $action_id;
		if( $action_id eq 'select' )
		{
			# if the field is not multiple then close the modal after selecting a value
			$json->{stop} = $self->{config}->{field}->get_property( 'multiple' ) ? 0 : 1;
			$json->{reload} = 1;
		}
		elsif( $action_id eq 'deselect' )
		{
			$json->{stop} = 0;
			$json->{reload} = 1;
		}
		elsif( $action_id eq 'search' )
		{
			$json->{stop} = 0;
			$json->{reload} = 0;
			$json->{insert} = delete $self->{processor}->{insert};
			$json->{insert_to} = delete $self->{processor}->{insert_to};
		}
		else
		{
			$json->{stop} = 1;
			$json->{reload} = 1;
		}
        }

        return $json;
}

sub render_title
{
	my( $self ) = @_;

	my $field = $self->{config}->{field};
	my $dataset = defined $field ? $self->{session}->dataset( $field->property( 'datasetid' ) ) : undef;

	if( defined $dataset && $self->{session}->get_lang->has_phrase( "Plugin/InputForm/Component/Modal/ItemSearch:add_item:".$dataset->confid() ) )
	{
		return $self->html_phrase( 'add_item:'.$dataset->render_name );
	}

	return $self->SUPER::render_title();	
}

sub render_content
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $frag = $session->make_doc_fragment;
	
	my $divid = $self->{prefix}."_results";
	my $qid = $self->{prefix}."_q";
	my $buttonid = $self->{prefix}."_modal_search";

	my $form = $frag->appendChild( $self->render_form );

# TOP BAR
	my $topbar = $form->appendChild( $session->make_element( 'div', class => 'ep_modal_bar' ) );

	$topbar->appendChild( $session->make_element( 'input', 
		name => 'q', 
		type => 'text', 
		id => $qid, 
		class => 'ep_dataobjref_search_q',
		autocomplete => 'off'
	) );

	# via CSS selector?
	my $loading_handler = <<H;
function(object, el) {
	\$( '$divid' ).update('<span></span>'); 
	\$( '$self->{prefix}' ).eprints.loading( \$( '$divid' ) );
}

H

	# [Search]
	my $search = $topbar->appendChild( $self->render_modal_action_button( 
		action => 'search',
		value => $session->phrase( 'lib/submissionform:action_search' ),
		handler => $loading_handler,
		id => $buttonid,
	) );
	
# RESULT LIST

	# the container that will receive the results
	my $results = $form->appendChild( $session->make_element( 'div', 
		class => 'ep_modal_results_list', 
		id => $divid 
	) );
	$results->appendChild( $self->html_phrase( 'placeholder' ) );

	# [Close]
        my $button_bar = $form->appendChild( $session->make_element( 'div', class => 'ep_modal_button_bar' ) );
        $button_bar->appendChild( $self->render_modal_action_button(
                        action => 'cancel',
                        value => $session->phrase( 'lib/submissionform:action_close' )
        ) );

	$form->appendChild( $session->make_javascript( <<JS ) );

// focus the text input
\$( '$qid' ).focus();;

// run the search when user has entered more than 3 chars
\$( '$qid' ).observe( 'keyup', function(event) {

	var text = \$( '$qid' ).value;
	if( text != null && text.length > 3 )
		\$( '$buttonid' ).click();

} );


// action handlers when the actions select/deselect are performed
if( \$( $self->{prefix} ) != null ) {

        \$( $self->{prefix} ).eprints.registerActionHandler( 'select', function (object, el) {

                el.addClassName( 'ep_result_selected' );
                var input = el.down( 'input' );
                if( input )
                {
			input.setAttribute( 'checked', 'checked' );
			el.setAttribute( 'data-internal', 'deselect' );
			object.initialize_modal_action( el );
                }
        } );
        
	\$( $self->{prefix} ).eprints.registerActionHandler( 'deselect', function (object, el) {

                el.removeClassName( 'ep_result_selected' );
                var input = el.down( 'input' );
                if( input )
                {
			input.removeAttribute( 'checked' );
			el.setAttribute( 'data-internal', 'select' );
			object.initialize_modal_action( el );
                }
        } );

}
JS


	return $frag;
}	

sub action_deselect
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	# the reference dataobj i.e. the one stored in the dataobjref field
	my $dataobjid = $self->{processor}->{action_param} or return;

	# $item is the object which has a Dataobjref field 
	my $item = $self->{workflow}->{item};
	my $field = $self->{config}->{field};
	my $dataset = $self->{session}->dataset( $field->property( 'datasetid' ) );

	# multiple field?
	if( $field->property( 'multiple' ) )
	{
		my $values = $item->value( $field->name );
		my @new_values;
		foreach(@$values)
		{
			next if( $_->{id} == $1 );
			push @new_values, $_;
		}
		$item->set_value( $field->name, \@new_values );
	}
	else
	{
		my $value = $item->value( $field->name );
		if( $value->{id} == $1 )
		{
			$item->set_value( $field->name, undef );
		}
	}

	$item->commit;

}

sub action_select
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	# the reference dataobj i.e. the one stored in the dataobjref field
	my $dataobjid = $self->{processor}->{action_param} or return;

	# $item is the object which has a Dataobjref field 
	my $item = $self->{workflow}->{item};
	my $field = $self->{config}->{field};
	my $dataset = $self->{session}->dataset( $field->property( 'datasetid' ) );

	# $dataobj is the target dataobj from the Dataobjref field
	my $dataobj = $dataset->dataobj( $dataobjid );

	# need to know the extra sub-fields too
	my $new_value = { id => $dataobj->id };
	foreach my $subfield ( @{$field->property( 'fields_cache' ) || [] } )
	{
		my $name = $subfield->property( 'sub_name' );
		next if( $name eq 'id' );
		if( !$dataobj->dataset->has_field( $name ) )
		{
			if( $name eq 'title' )	# 'title' for a dataobjref field is the dataobj's description
			{
				$new_value->{$name} = EPrints::Utils::tree_to_utf8( $dataobj->render_description );
			}
			next;
		}
		$new_value->{$name} = $dataobj->value( $name );
	}

	if( $field->get_property( 'multiple' ) )
	{
		my $values = $item->value( $field->name );
		my %existing_values = map { $_->{id} => 1 } @{$values||[]};
		# don't add value if already selected
		return if( $existing_values{$dataobj->id} );
		push @$values, $new_value;
		$item->set_value( $field->name, $values );
	}
	else
	{
		$item->set_value( $field->name, $new_value );
	}

	$item->commit;

}

sub action_search
{
	my( $self ) = @_;

	$self->{processor}->{redirect} = $self->{processor}->{return_to}
		if !$self->wishes_to_export;

	my $session = $self->{session};

	my $q = $session->param( 'q' );

	$q .= "*" unless( $q =~ /[\*\s]$/ );

	my $field = $self->{config}->{field};

	my $tdataset = $session->dataset( $field->property( "datasetid" ) );

	my $processor = EPrints::ScreenProcessor->new(
		session => $session,
		dataset => $tdataset,
		screenid => "Search",
		searchid => "simple",
	);

	$processor->screen->properties_from;

	# override the settings from Screen::Search
	$processor->{sconf}->{keep_cache} = 0;
	$processor->{sconf}->{limit} = 10;
	$processor->{sconf}->{satisfy_all} = 0;

	$processor->screen->from;

	$self->send_results( $processor->{results} );
}

# + $offset, $max
sub send_results
{
	my( $self, $results ) = @_;
	
	my $session = $self->{session};

	$self->{processor}->{insert_to} = $self->{prefix}."_results";

	if( $results->count == 0 ) 
	{
		$self->{processor}->{insert} = $session->xhtml->to_xhtml( $self->html_phrase( 'no_results' ) );
		return;
	}
	
	my $dataobj = $self->{workflow}->{item};
	my $field = $self->{config}->{field};
	my %current_values;

	if( $field->property( 'multiple' ) )
	{
		%current_values = map { $_->{id} => 1 } @{$dataobj->value( $field->name ) || [] };
	}
	elsif( $dataobj->is_set( $field->name ) )
	{
		$current_values{$dataobj->value( $field->name )->{id}} = 1;
	}

	my $frag = $session->make_doc_fragment;
	my $main_container = $frag->appendChild( $session->make_element( 'div' ) );

	$results->map( sub {
	
		my $match = $_[2];	
		
		my $is_selected = defined $current_values{$match->id};
		
		my $cid = $self->{prefix}."_container_".$match->id;

		my $action = ( $is_selected ) ? 'deselect' : 'select';
		my $classes = ( $is_selected ) ? 'ep_result_selected' : '';
		$classes .= " ep_result ep_component_action";
		
		my $container = $main_container->appendChild( $session->make_element( 'div', 
				id => $cid, 
				class => $classes,
				'data-internal' => $action,
				'data-internal-param' => $match->id,	# extra param required to perform the action - here it's the ID of the dataobj we want to select
				'data-internal-element' => $cid,	# an HTML element to send to the JS ActionHandler which is executed when the JS Event ('click' here) is fired 
		) );

		$container->appendChild( $match->render_citation( 'brief' ) );
		my $checkbox = $container->appendChild( $session->make_element( 'input', type => 'checkbox' ) );
		if( $is_selected )
		{
			$checkbox->setAttribute( 'checked', 'checked' );
		}
	
	} );

	$self->{processor}->{insert} = $session->xhtml->to_xhtml( $frag );

}


1;
