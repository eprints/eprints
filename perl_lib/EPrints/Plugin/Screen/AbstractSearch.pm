package EPrints::Plugin::Screen::AbstractSearch;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ update search newsearch export_redir export /]; 

	return $self;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 0;
}

sub allow_export_redir { return 0; }

sub action_export_redir
{
	my( $self ) = @_;

	my $cacheid = $self->{session}->param( "cache" );
	my $format = $self->{session}->param( "output" );
	if( !defined $format )
	{
		$self->{processor}->{search_subscreen} = "results";
		$self->{processor}->add_message(
			"error",
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ) );
		return;
	}

	$self->{processor}->{redirect} = $self->export_url( $format )."&cache=".$cacheid;
}

sub export_url
{
	my( $self, $format ) = @_;

	my $plugin = $self->{session}->plugin( "Export::".$format );
	if( !defined $plugin )
	{
		EPrints::abort( "No such plugin: $format\n" );	
	}

	my $url = URI->new( $self->{session}->get_uri() . "/export_" . $self->{session}->get_repository->get_id . "_" . $format . $plugin->param( "suffix" ) );

	$url->query_form(
		screen => $self->{processor}->{screenid},
		_action_export => 1,
		output => $format,
		exp => $self->{processor}->{search}->serialise,
		n => $self->{session}->param( "n" ),
	);

	return $url;
}

sub allow_export { return 0; }

sub action_export
{
	my( $self ) = @_;

	$self->run_search;

	$self->{processor}->{search_subscreen} = "export";

	return;
}

sub allow_search { return 1; }

sub action_search
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "results";

	$self->run_search;
}

sub allow_update { return 1; }

sub action_update
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "form";
}

sub allow_newsearch { return 1; }

sub action_newsearch
{
	my( $self ) = @_;

	$self->{processor}->{search}->clear;

	$self->{processor}->{search_subscreen} = "form";
}

sub run_search
{
	my( $self ) = @_;

	my $list = $self->{processor}->{search}->perform_search();

	my $error = $self->{processor}->{search}->{error};
	if( defined $error )
	{	
		$self->{processor}->add_message( "error", $error );
		$self->{processor}->{search_subscreen} = "form";
	}

	if( $list->count == 0 && !$self->{processor}->{search}->{show_zero_results} )
	{
		$self->{processor}->add_message( "warning",
			$self->{session}->html_phrase(
				"lib/searchexpression:noresults") );
		$self->{processor}->{search_subscreen} = "form";
	}

	$self->{processor}->{results} = $list;
}	

sub search_dataset
{
	my( $self ) = @_;

	return undef;
}

sub search_filters
{
	my( $self ) = @_;

	return;
}


sub from
{
	my( $self ) = @_;

	# This rather oddly now checks for the special case of one parameter, but
	# that parameter being a screenid, in which case the search effectively has
	# no parameters and should not default to action = 'search'.
	# maybe this can be removed later, but for a minor release this seems safest.
	if( !EPrints::Utils::is_set( $self->{processor}->{action} ) )
	{
		my @paramlist = $self->{session}->param();
		my $has_params = 0;
		$has_params = 1 if( scalar @paramlist );
		$has_params = 0 if( scalar @paramlist == 1 && $paramlist[0] eq 'screen' );
		if( $has_params )
		{
			$self->{processor}->{action} = "search";
		}
	}

	$self->{processor}->{search} = new EPrints::Search(
		keep_cache => 1,
		session => $self->{session},
		filters => [$self->search_filters],
		dataset => $self->search_dataset,
		%{$self->{processor}->{sconf}} );


	$self->{actions} = [qw/ update search newsearch export_redir export /]; 
	if( 	$self->{processor}->{action} eq "search" || 
	 	$self->{processor}->{action} eq "update" || 
	 	$self->{processor}->{action} eq "export" || 
	 	$self->{processor}->{action} eq "export_redir"  )
	{
		my $loaded = 0;
		my $id = $self->{session}->param( "cache" );
		if( defined $id )
		{
			$loaded = $self->{processor}->{search}->from_cache( $id );
		}
	
		if( !$loaded )
		{
			my $exp = $self->{session}->param( "exp" );
			if( defined $exp )
			{
				$self->{processor}->{search}->from_string( $exp );
				# cache expired...
				$loaded = 1;
			}
		}
	
		my @problems;
		if( !$loaded )
		{
			foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
			{
				my $prob = $sf->from_form();
				if( defined $prob )
				{
					$self->{processor}->add_message( "warning", $prob );
				}
			}
		}
	}
	my $anyall = $self->{session}->param( "satisfyall" );

	if( defined $anyall )
	{
		$self->{processor}->{search}->{satisfy_all} = ( $anyall eq "ALL" );
	}

	my $order_opt = $self->{session}->param( "order" );
	if( !defined $order_opt )
	{
		$order_opt = "";
	}

	my $allowed_order = 0;
	foreach my $order_key ( keys %{$self->{processor}->{sconf}->{order_methods}} )
	{
		$allowed_order = 1 if( $order_opt eq $self->{processor}->{sconf}->{order_methods}->{$order_key} );
	}

	if( $allowed_order )
	{
		$self->{processor}->{search}->{custom_order} = $order_opt;
	}
	else
	{
		$self->{processor}->{search}->{custom_order} = 
			 $self->{processor}->{sconf}->{order_methods}->{$self->{processor}->{sconf}->{default_order}};
	}

	# do actions
	$self->SUPER::from;


	if( $self->{processor}->{search}->is_blank && ! $self->{processor}->{search}->{allow_blank} )
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

sub render
{
	my( $self ) = @_;

	my $subscreen = $self->{processor}->{search_subscreen};
	if( !defined $subscreen || $subscreen eq "form" )
	{
		return $self->render_search_form;	
	}
	if( $subscreen eq "results" )
	{
		return $self->render_results;	
	}

	$self->{processor}->add_message(
		"error",
		$self->{session}->html_phrase( "lib/searchexpression:bad_subscreen",
			subscreen => $self->{session}->make_text($subscreen) ) );

	return $self->render_search_form;	
}

sub _get_export_plugins
{
	my( $self, $include_not_advertised ) = @_;

	my $is_advertised = 1;
	my %opts =  (
			type=>"Export",
			can_accept=>"list/".$self->{processor}->{search}->{dataset}->confid, 
			is_visible=>$self->_vis_level,
	);
	unless( $include_not_advertised ) { $opts{is_advertised} = 1; }
	return $self->{session}->plugin_list( %opts );
}

sub _vis_level
{
	my( $self ) = @_;

	return "all";
}

sub render_title
{
	my( $self ) = @_;

	my $subscreen = $self->{processor}->{search_subscreen};
	if( defined $subscreen && $subscreen eq "results" )
	{
		return $self->{processor}->{search}->render_conditions_description;
	}

	my $phraseid = $self->{processor}->{sconf}->{"title_phrase"};
	if( defined $phraseid )
	{
		return $self->{"session"}->html_phrase( $phraseid );
	}
	return $self->SUPER::render_title;
}

sub render_links
{
	my( $self ) = @_;

	if( $self->{processor}->{search_subscreen} ne "results" )
	{
		return $self->SUPER::render_links;
	}

	my @plugins = $self->_get_export_plugins;
	my $links = $self->{session}->make_doc_fragment();

	my $escexp = $self->{processor}->{search}->serialise;
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $self->{session}->plugin( $plugin_id );
		my $url = URI::http->new;
		$url->query_form(
			cache => $self->{cache_id},
			exp => $escexp,
			output => $id,
			_action_export_redir => 1
			);
		my $link = $self->{session}->make_element( 
			"link", 
			rel=>"alternate",
			href=>$url,
			type=>$plugin->param("mimetype"),
			title=>EPrints::XML::to_string( $plugin->render_name ), );
		$links->appendChild( $self->{session}->make_text( "\n    " ) );
		$links->appendChild( $link );
	}

	$links->appendChild( $self->SUPER::render_links );

	return $links;
}

sub render_export_bar
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{results} || 
		ref($self->{processor}->{results}) ne "EPrints::List" )
	{
                return $self->{session}->make_doc_fragment;
	}

	my @plugins = $self->_get_export_plugins;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $order = $self->{processor}->{search}->{custom_order};
	my $escexp = $self->{processor}->{search}->serialise;
	my $session = $self->{session};
	if( scalar @plugins == 0 ) 
	{
		return $session->make_doc_fragment;
	}

	my $feeds = $session->make_doc_fragment;
	my $tools = $session->make_doc_fragment;
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $session->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		if( $plugin->is_feed || $plugin->is_tool )
		{
			my $type = "feed";
			$type = "tool" if( $plugin->is_tool );
			my $span = $session->make_element( "span", class=>"ep_search_$type" );
			my $url = $self->export_url( $id );
			my $a1 = $session->render_link( $url );
			my $icon = $session->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $session->render_link( $url );
			$a2->appendChild( $dom_name );
			$span->appendChild( $a1 );
			$span->appendChild( $session->make_text( " " ) );
			$span->appendChild( $a2 );

			if( $type eq "tool" )
			{
				$tools->appendChild( $session->make_text( " " ) );
				$tools->appendChild( $span );	
			}
			if( $type eq "feed" )
			{
				$feeds->appendChild( $session->make_text( " " ) );
				$feeds->appendChild( $span );	
			}
		}
		else
		{
			my $option = $session->make_element( "option", value=>$id );
			$option->appendChild( $dom_name );
			$options->{EPrints::XML::to_string($dom_name)} = $option;
		}
	}

	my $select = $session->make_element( "select", name=>"output" );
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $session->make_doc_fragment;
	$button->appendChild( $session->render_button(
			name=>"_action_export_redir",
			value=>$session->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$session->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	$button->appendChild( 
		$session->render_hidden_field( "order", $order ) ); 
	$button->appendChild( 
		$session->render_hidden_field( "cache", $cacheid ) ); 
	$button->appendChild( 
		$session->render_hidden_field( "exp", $escexp, ) );

	my $form = $self->{session}->render_form( "GET" );
	$form->appendChild( $session->html_phrase( "lib/searchexpression:export_section",
					feeds => $feeds,
					tools => $tools,
					count => $session->make_text( 
						$self->{processor}->{results}->count ),
					menu => $select,
					button => $button ));

	return $form;
}

sub get_basic_controls_before
{
	my( $self ) = @_;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my $baseurl = $self->{session}->get_uri . "?cache=$cacheid&exp=$escexp&screen=".$self->{processor}->{screenid};
	$baseurl .= "&order=".$self->{processor}->{search}->{custom_order};
	my @controls_before = (
		{
			url => "$baseurl&_action_update=1",
			label => $self->{session}->html_phrase( "lib/searchexpression:refine" ),
		},
		{
			url => $self->{session}->get_uri . "?screen=".$self->{processor}->{screenid},
			label => $self->{session}->html_phrase( "lib/searchexpression:new" ),
		}
	);

	return @controls_before;
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;
}

sub paginate_opts
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{results} || 
		ref($self->{processor}->{results}) ne "EPrints::List" )
	{
                return $self->{session}->make_doc_fragment;
	}

	my %bits = ();

	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my @controls_before = $self->get_controls_before;
	
	my $export_div = $self->{session}->make_element( "div", class=>"ep_search_export" );
	$export_div->appendChild( $self->render_export_bar );

	my $type = $self->{session}->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );
	my $container;
	if( $type eq "table_row" )
	{
		$container = $self->{session}->make_element( 
				"table", 
				class=>"ep_paginate_list" );
	}
	else
	{
		$container = $self->{session}->make_element( 
				"div", 
				class=>"ep_paginate_list" );
	}

	my $order_div = $self->{session}->make_element( "div", class=>"ep_search_reorder" );
	my $form = $self->{session}->render_form( "GET" );
	$order_div->appendChild( $form );
	$form->appendChild( $self->{session}->html_phrase( "lib/searchexpression:order_results" ) );
	$form->appendChild( $self->{session}->make_text( ": " ) );
	$form->appendChild( $self->render_order_menu );

	$form->appendChild( $self->{session}->render_button(
			name=>"_action_search",
			value=>$self->{session}->phrase( "lib/searchexpression:reorder_button" ) ) );
	$form->appendChild( 
		$self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	$form->appendChild( 
		$self->{session}->render_hidden_field( "exp", $escexp, ) );

	return (
		pins => \%bits,
		controls_before => \@controls_before,
		above_results => $export_div,
		controls_after => $order_div,
		params => { 
			screen => $self->{processor}->{screenid},
			_action_search => 1,
			cache => $cacheid,
			exp => $escexp,
		},
		render_result => sub { return $self->render_result_row( @_ ); },
		render_result_params => $self,
		page_size => $self->{processor}->{sconf}->{page_size},
		container => $container,
	);
}

sub render_results_intro
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub render_results
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{results} || 
		ref($self->{processor}->{results}) ne "EPrints::List" )
	{
                return $self->{session}->make_doc_fragment;
	}

	my %opts = $self->paginate_opts;

	my $page = $self->{session}->make_doc_fragment;
	$page->appendChild( $self->render_results_intro );
	$page->appendChild( 
		EPrints::Paginate->paginate_list( 
			$self->{session}, 
			"search", 
			$self->{processor}->{results}, 
			%opts ) );

	return $page;
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	my $type = $session->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );

	if( $type eq "table_row" )
	{
		return $result->render_citation_link;
	}

	my $div = $session->make_element( "div", class=>"ep_search_result" );
	$div->appendChild( $result->render_citation_link( "default" ) );
	return $div;
}

sub get_citation_id 
{
	my( $self ) = @_;

	return $self->{processor}->{sconf}->{citation} || "default";
}

sub render_search_form
{
	my( $self ) = @_;

	my $form = $self->{session}->render_form( "get" );
	$form->appendChild( 
		$self->{session}->render_hidden_field ( "screen", $self->{processor}->{screenid} ) );		

	my $pphrase = $self->{processor}->{sconf}->{"preamble_phrase"};
	if( defined $pphrase )
	{
		$form->appendChild( $self->{"session"}->html_phrase( $pphrase ));
	}

	$form->appendChild( $self->render_controls );

	my $table = $self->{session}->make_element( "table", class=>"ep_search_fields" );
	$form->appendChild( $table );

	$table->appendChild( $self->render_search_fields );

	$table->appendChild( $self->render_anyall_field );

	$table->appendChild( $self->render_order_field );

	$form->appendChild( $self->render_controls );

	return( $form );
}


sub render_search_fields
{
	my( $self ) = @_;

	my $frag = $self->{session}->make_doc_fragment;

	foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
	{
		$frag->appendChild( 
			$self->{session}->render_row_with_help( 
				help_prefix => $sf->get_form_prefix."_help",
				help => $sf->render_help,
				label => $sf->render_name,
				field => $sf->render,
				no_toggle => ( $sf->{show_help} eq "always" ),
				no_help => ( $sf->{show_help} eq "never" ),
			 ) );
	}

	return $frag;
}


sub render_anyall_field
{
	my( $self ) = @_;

	my @sfields = $self->{processor}->{search}->get_non_filter_searchfields;
	if( (scalar @sfields) < 2 )
	{
		return $self->{session}->make_doc_fragment;
	}

	my $menu = $self->{session}->render_option_list(
			name=>"satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{processor}->{search}->{satisfy_all} && $self->{processor}->{search}->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{session}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{session}->phrase( 
						"lib/searchexpression:any" )} );

	return $self->{session}->render_row_with_help( 
			no_help => 1,
			label => $self->{session}->html_phrase( 
				"lib/searchexpression:must_fulfill" ),  
			field => $menu,
	);
}

sub render_controls
{
	my( $self ) = @_;

	my $div = $self->{session}->make_element( 
		"div" , 
		class => "ep_search_buttons" );
	$div->appendChild( $self->{session}->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => $self->{session}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{session}->phrase( "lib/searchexpression:action_search" ) )
 	);
	return $div;
}



sub render_order_field
{
	my( $self ) = @_;

	return $self->{session}->render_row_with_help( 
			no_help => 1,
			label => $self->{session}->html_phrase( 
				"lib/searchexpression:order_results" ),  
			field => $self->render_order_menu,
	);
}

sub render_order_menu
{
	my( $self ) = @_;

	my $raworder = $self->{processor}->{search}->{custom_order};

	my $order = $self->{processor}->{sconf}->{default_order};

	my $methods = $self->{processor}->{sconf}->{order_methods};

	my %labels = ();
	foreach( keys %$methods )
	{
		$order = $raworder if( $methods->{$_} eq $raworder );
                $labels{$methods->{$_}} = $self->{session}->phrase(
                	"ordername_".$self->{processor}->{search}->{dataset}->confid() . "_" . $_ );
        }

	return $self->{session}->render_option_list(
		name=>"order",
		values=>[values %{$methods}],
		default=>$order,
		labels=>\%labels );
}

	
	

# $method_map = $searche->order_methods

sub wishes_to_export
{
	my( $self ) = @_;

	return 0 unless $self->{processor}->{search_subscreen} eq "export";

	my $format = $self->{session}->param( "output" );
	my $n = $self->{session}->param( "n" );

	my @plugins = $self->_get_export_plugins( 1 );
		
	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "Export::$format" ) { $ok = 1; last; } }
	unless( $ok ) 
	{
		$self->{processor}->{search_subscreen} = "results";
		$self->{processor}->add_message(
			"error",
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ) );
		return;
	}
	
	$self->{processor}->{export_plugin} = $self->{session}->plugin( "Export::$format" );
	$self->{processor}->{export_format} = $format;
	$self->{processor}->{export_n} = $n;
	
	return 1;
}


sub export
{
	my( $self ) = @_;

	my $results = $self->{processor}->{results};
	my $n = $self->{processor}->{export_n};
	if( $n && $n > 0 )
	{
		my $ids = $results->get_ids( 0, $n );
		$results = EPrints::List->new(
			session => $self->{session},
			dataset => $results->{dataset},
			ids => $ids );
	}

	my $format = $self->{processor}->{export_format};
	my $plugin = $self->{session}->plugin( "Export::" . $format );
	$plugin->initialise_fh( *STDOUT );
	$results->export( $format, fh => *STDOUT );
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->{processor}->{export_plugin}->param("mimetype") 
}






1;
