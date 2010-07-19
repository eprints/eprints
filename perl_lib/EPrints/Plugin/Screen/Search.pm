package EPrints::Plugin::Screen::Search;

use EPrints::Plugin::Screen::AbstractSearch;
@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [];
	push @{$self->{actions}}, "advanced";

	return $self;
}

sub datasets
{
	my( $self ) = @_;

	my $session = $self->{session};

	my @datasets;

	foreach my $datasetid ($session->get_dataset_ids)
	{
		local $self->{processor}->{dataset} = $session->dataset( $datasetid );
		next if !$self->can_be_viewed();
		push @datasets, $datasetid;
	}

	return @datasets;
}

sub search_dataset
{
	my( $self ) = @_;

	return $self->{processor}->{dataset};
}

sub search_filters
{
	my( $self ) = @_;

	return;
}

sub allow_advanced { &can_be_viewed }
sub allow_export { &can_be_viewed }
sub allow_export_redir { &can_be_viewed }
sub can_be_viewed
{
	my( $self ) = @_;

	# note this method is also used by $self->datasets()

	my $dataset = $self->{processor}->{dataset};
	return 0 if !defined $dataset;

	if( $dataset->id eq "archive" )
	{
		return $self->allow( "eprint_search" );
	}
	else
	{
		return $self->allow( $dataset->id . "/search" );
	}
}

sub get_controls_before
{
	my( $self ) = @_;

	my @controls = $self->get_basic_controls_before;

# Maybe add links to the pagination controls to switch between simple/advanced
#	if( $self->{processor}->{searchid} eq "simple" )
#	{
#		push @controls, {
#			url => "advanced",
#			label => $self->{session}->html_phrase( "lib/searchexpression:advanced_link" ),
#		};
#	}

	return @controls;
}

sub render_hidden_bits
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	$frag->appendChild( $self->SUPER::render_hidden_bits );
	$frag->appendChild( $session->xhtml->hidden_field( dataset => $self->{processor}->{dataset}->id ) );

	return $frag;
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	return $result->render_citation_link(
			$self->{processor}->{sconf}->{citation},  #undef unless specified
			n => [$n,"INTEGER"] );
}

sub export_url
{
	my( $self, $format ) = @_;

	my $plugin = $self->{session}->plugin( "Export::".$format );
	if( !defined $plugin )
	{
		EPrints::abort( "No such plugin: $format\n" );	
	}

	my $url = URI->new( $self->{session}->current_url() . "/export_" . $self->{session}->get_repository->get_id . "_" . $format . $plugin->param( "suffix" ) );

	$url->query_form(
		screen => $self->{processor}->{screenid},
		dataset => $self->search_dataset->id,
		_action_export => 1,
		output => $format,
		exp => $self->{processor}->{search}->serialise,
		n => $self->{session}->param( "n" ),
	);

	return $url;
}

sub action_advanced
{
	my( $self ) = @_;

	my $adv_url;
	my $datasetid = $self->{session}->param( "dataset" );
	$datasetid = "archive" if !defined $datasetid; # something odd happened
	if( $datasetid eq "archive" )
	{
		$adv_url = $self->{session}->current_url( path => "cgi", "search/advanced" );
	}
	else
	{
		$adv_url = $self->{session}->current_url( path => "cgi", "search/$datasetid/advanced" );
	}

	$self->{processor}->{redirect} = $adv_url;
}

sub render_search_form
{
	my( $self ) = @_;

	if( $self->{processor}->{searchid} eq "simple" )
	{
		return $self->render_simple_form;
	}
	else
	{
		return $self->SUPER::render_search_form;
	}
}

sub render_preamble
{
	my( $self ) = @_;

	my $pphrase = $self->{processor}->{sconf}->{"preamble_phrase"};
	$pphrase = "cgi/advsearch:preamble" if !defined $pphrase;

	return $self->{"session"}->html_phrase( $pphrase );
}

sub render_simple_form
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xhtml = $session->xhtml;
	my $xml = $session->xml;
	my $input;

	my $div = $xml->create_element( "div", class => "ep_block" );

	my $form = $self->{session}->render_form( "get" );
	$div->appendChild( $form );

	# avoid adding "dataset", which is selectable here
	$form->appendChild( $self->SUPER::render_hidden_bits );

	# maintain the order if it was specified (might break if dataset is
	# changed)
	$input = $xhtml->hidden_field( "order", $session->param( "order" ) );
	$form->appendChild( $input );

#	$form->appendChild( $self->render_preamble );

#	my( $sfield ) = $self->{processor}->{search}->get_non_filter_searchfields;
#	$form->appendChild( $sfield->render );
	$form->appendChild( $self->{processor}->{search}->render_simple_fields );

	$input = $xml->create_element( "input",
		type => "submit",
		name => "_action_search",
		value => $self->{session}->phrase( "lib/searchexpression:action_search" ),
		class => "ep_form_action_button",
	);
	$form->appendChild( $input );

	$input = $xml->create_element( "input",
		type => "submit",
		name => "_action_advanced",
		value => $self->{session}->phrase( "lib/searchexpression:advanced_link" ),
		style => "border: none; text-decoration: underline; background: none; color: #00f; cursor: pointer; font-size: 80%;",
#		class => "ep_form_action_button",
	);
	$form->appendChild( $input );

	$form->appendChild( $xml->create_element( "br" ) );

	$form->appendChild( $self->render_dataset );

	return( $div );
}

sub render_dataset
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $xhtml = $session->xhtml;
	my $xml = $session->xml;

	my $frag = $xml->create_document_fragment;

	my @datasetids = $self->datasets;

	return $frag if @datasetids <= 1;

	foreach my $datasetid (sort @datasetids)
	{
		my $input = $xml->create_element( "input",
			name => "dataset",
			type => "radio",
			value => $datasetid );
		if( $datasetid eq $self->{processor}->{dataset}->id )
		{
			$input->setAttribute( checked => "yes" );
		}
		my $label = $xml->create_element( "label" );
		$frag->appendChild( $label );
		$label->appendChild( $input );
		$label->appendChild( $session->html_phrase( "datasetname_$datasetid" ) );
	}

	return $frag;
}

sub from
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $processor = $self->{processor};
	my $sconf = $processor->{sconf};

	# This rather oddly now checks for the special case of one parameter, but
	# that parameter being a screenid, in which case the search effectively has
	# no parameters and should not default to action = 'search'.
	# maybe this can be removed later, but for a minor release this seems safest.
	if( !EPrints::Utils::is_set( $self->{processor}->{action} ) )
	{
		my %params = map { $_ => 1 } $self->{session}->param();
		delete $params{screen};
		delete $params{dataset};
		if( scalar keys %params )
		{
			$self->{processor}->{action} = "search";
		}
	}

	my $format = $processor->{searchid} . "/" . $processor->{dataset}->base_id;
	my @plugins = $session->get_plugins(
		{
			session => $session,
			dataset => $self->search_dataset,
			keep_cache => 1,
			%{$processor->{sconf}},
		},
		type => "Search",
		can_search => $format,
	);
	if( !@plugins )
	{
		EPrints->abort( "No available search plugin for $format" );
	}
	@plugins = sort { $b->param( "qs" ) <=> $a->param( "qs" ) } @plugins;
	
	my $searchexp = $processor->{search} = $plugins[0];

	if(
		$self->{processor}->{action} eq "search" || 
	 	$self->{processor}->{action} eq "update" || 
	 	$self->{processor}->{action} eq "export" || 
	 	$self->{processor}->{action} eq "export_redir"
	  )
	{
		my $ok = 0;
		if( my $id = $session->param( "cache" ) )
		{
			$ok = $searchexp->from_cache( $id );
		}
		if( !$ok && (my $exp = $session->param( "exp" )) )
		{
			# cache expired
			$ok = $searchexp->from_string( $exp );
		}
		if( !$ok )
		{
			for( $searchexp->from_form )
			{
				$self->{processor}->add_message( "warning", $_ );
			}
		}
	}

	$sconf->{order_methods} = {} if !defined $sconf->{order_methods};
	if( $searchexp->param( "result_order" ) )
	{
		$sconf->{order_methods}->{"byrelevance"} = "";
	}

	# have we been asked to reorder?
	if( defined( my $order_opt = $self->{session}->param( "order" ) ) )
	{
		my $allowed_order = 0;
		foreach my $custom_order ( values %{$sconf->{order_methods}} )
		{
			$allowed_order = 1 if $order_opt eq $custom_order;
		}

		my $custom_order;
		if( $allowed_order )
		{
			$custom_order = $order_opt;
		}
		elsif( defined $sconf->{default_order} )
		{
			$custom_order = $sconf->{order_methods}->{$sconf->{default_order}};
		}
		else
		{
			$custom_order = "";
		}

		$searchexp->{custom_order} = $custom_order;
	}

	# do actions
	$self->EPrints::Plugin::Screen::from;

	if( $searchexp->is_blank )
	{
		if( $self->{processor}->{action} eq "search" )
		{
			$self->{processor}->add_message( "warning",
				$self->{session}->html_phrase( 
					"lib/searchexpression:least_one" ) );
		}
		$self->{processor}->{search_subscreen} = "form";
	}
}

1;
