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

	my $cacheid = $self->{handle}->param( "cache" );
	my $format = $self->{handle}->param( "output" );
	if( !defined $format )
	{
		$self->{processor}->{search_subscreen} = "results";
		$self->{processor}->add_message(
			"error",
			$self->{handle}->html_phrase( "lib/searchexpression:export_error_format" ) );
		return;
	}

	$self->{processor}->{redirect} = $self->export_url( $format )."&cache=".$cacheid;
}

sub export_url
{
	my( $self, $format ) = @_;

	my $plugin = $self->{handle}->plugin( "Export::".$format );
	if( !defined $plugin )
	{
		EPrints::abort( "No such plugin: $format\n" );	
	}

	my $url = URI->new( $self->{handle}->get_uri() . "/export_" . $self->{handle}->get_repository->get_id . "_" . $format . $plugin->param( "suffix" ) );

	$url->query_form(
		screen => $self->{processor}->{screenid},
		_action_export => 1,
		output => $format,
		exp => $self->{processor}->{search}->serialise,
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
			$self->{handle}->html_phrase(
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
		my @paramlist = $self->{handle}->param();
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
		handle => $self->{handle},
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
		my $id = $self->{handle}->param( "cache" );
		if( defined $id )
		{
			$loaded = $self->{processor}->{search}->from_cache( $id );
		}
	
		if( !$loaded )
		{
			my $exp = $self->{handle}->param( "exp" );
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
	my $anyall = $self->{handle}->param( "satisfyall" );

	if( defined $anyall )
	{
		$self->{processor}->{search}->{satisfy_all} = ( $anyall eq "ALL" );
	}

	my $order_opt = $self->{handle}->param( "order" );
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
				$self->{handle}->html_phrase( 
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
		$self->{handle}->html_phrase( "lib/searchexpression:bad_subscreen",
			subscreen => $self->{handle}->make_text($subscreen) ) );

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
	unless( $include_not_advertised ) { $is_advertised = 1; }
	return $self->{handle}->plugin_list( %opts );
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
		return $self->{handle}->html_phrase( $phraseid );
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
	my $links = $self->{handle}->make_doc_fragment();

	my $escexp = $self->{processor}->{search}->serialise;
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $self->{handle}->plugin( $plugin_id );
		my $url = URI::http->new;
		$url->query_form(
			cache => $self->{cache_id},
			exp => $escexp,
			output => $id,
			_action_export_redir => 1
			);
		my $link = $self->{handle}->make_element( 
			"link", 
			rel=>"alternate",
			href=>$url,
			type=>$plugin->param("mimetype"),
			title=>EPrints::XML::to_string( $plugin->render_name ), );
		$links->appendChild( $self->{handle}->make_text( "\n    " ) );
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
                return $self->{handle}->make_doc_fragment;
	}

	my @plugins = $self->_get_export_plugins;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $order = $self->{processor}->{search}->{custom_order};
	my $escexp = $self->{processor}->{search}->serialise;
	my $handle = $self->{handle};
	if( scalar @plugins == 0 ) 
	{
		return $handle->make_doc_fragment;
	}

	my $feeds = $handle->make_doc_fragment;
	my $tools = $handle->make_doc_fragment;
	my $options = {};
	foreach my $plugin_id ( @plugins ) 
	{
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $plugin = $handle->plugin( $plugin_id );
		my $dom_name = $plugin->render_name;
		if( $plugin->is_feed || $plugin->is_tool )
		{
			my $type = "feed";
			$type = "tool" if( $plugin->is_tool );
			my $span = $handle->make_element( "span", class=>"ep_search_$type" );
			my $url = $self->export_url( $id );
			my $a1 = $handle->render_link( $url );
			my $icon = $handle->make_element( "img", src=>$plugin->icon_url(), alt=>"[$type]", border=>0 );
			$a1->appendChild( $icon );
			my $a2 = $handle->render_link( $url );
			$a2->appendChild( $dom_name );
			$span->appendChild( $a1 );
			$span->appendChild( $handle->make_text( " " ) );
			$span->appendChild( $a2 );

			if( $type eq "tool" )
			{
				$tools->appendChild( $handle->make_text( " " ) );
				$tools->appendChild( $span );	
			}
			if( $type eq "feed" )
			{
				$feeds->appendChild( $handle->make_text( " " ) );
				$feeds->appendChild( $span );	
			}
		}
		else
		{
			my $option = $handle->make_element( "option", value=>$id );
			$option->appendChild( $dom_name );
			$options->{EPrints::XML::to_string($dom_name)} = $option;
		}
	}

	my $select = $handle->make_element( "select", name=>"output" );
	foreach my $optname ( sort keys %{$options} )
	{
		$select->appendChild( $options->{$optname} );
	}
	my $button = $handle->make_doc_fragment;
	$button->appendChild( $handle->render_button(
			name=>"_action_export_redir",
			value=>$handle->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$handle->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	$button->appendChild( 
		$handle->render_hidden_field( "order", $order ) ); 
	$button->appendChild( 
		$handle->render_hidden_field( "cache", $cacheid ) ); 
	$button->appendChild( 
		$handle->render_hidden_field( "exp", $escexp, ) );

	my $form = $self->{handle}->render_form( "GET" );
	$form->appendChild( $handle->html_phrase( "lib/searchexpression:export_section",
					feeds => $feeds,
					tools => $tools,
					count => $handle->make_text( 
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

	my $baseurl = $self->{handle}->get_uri . "?cache=$cacheid&exp=$escexp&screen=".$self->{processor}->{screenid};
	$baseurl .= "&order=".$self->{processor}->{search}->{custom_order};
	my @controls_before = (
		{
			url => "$baseurl&_action_update=1",
			label => $self->{handle}->html_phrase( "lib/searchexpression:refine" ),
		},
		{
			url => $self->{handle}->get_uri . "?screen=".$self->{processor}->{screenid},
			label => $self->{handle}->html_phrase( "lib/searchexpression:new" ),
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
                return $self->{handle}->make_doc_fragment;
	}

	my %bits = ();

	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my @controls_before = $self->get_controls_before;
	
	my $export_div = $self->{handle}->make_element( "div", class=>"ep_search_export" );
	$export_div->appendChild( $self->render_export_bar );

	my $type = $self->{handle}->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );
	my $container;
	if( $type eq "table_row" )
	{
		$container = $self->{handle}->make_element( 
				"table", 
				class=>"ep_paginate_list" );
	}
	else
	{
		$container = $self->{handle}->make_element( 
				"div", 
				class=>"ep_paginate_list" );
	}

	my $order_div = $self->{handle}->make_element( "div", class=>"ep_search_reorder" );
	my $form = $self->{handle}->render_form( "GET" );
	$order_div->appendChild( $form );
	$form->appendChild( $self->{handle}->html_phrase( "lib/searchexpression:order_results" ) );
	$form->appendChild( $self->{handle}->make_text( ": " ) );
	$form->appendChild( $self->render_order_menu );

	$form->appendChild( $self->{handle}->render_button(
			name=>"_action_search",
			value=>$self->{handle}->phrase( "lib/searchexpression:reorder_button" ) ) );
	$form->appendChild( 
		$self->{handle}->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	$form->appendChild( 
		$self->{handle}->render_hidden_field( "exp", $escexp, ) );

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

	return $self->{handle}->make_doc_fragment;
}

sub render_results
{
	my( $self ) = @_;

	if( !defined $self->{processor}->{results} || 
		ref($self->{processor}->{results}) ne "EPrints::List" )
	{
                return $self->{handle}->make_doc_fragment;
	}

	my %opts = $self->paginate_opts;

	my $page = $self->{handle}->make_doc_fragment;
	$page->appendChild( $self->render_results_intro );
	$page->appendChild( 
		EPrints::Paginate->paginate_list( 
			$self->{handle}, 
			"search", 
			$self->{processor}->{results}, 
			%opts ) );

	return $page;
}

sub render_result_row
{
	my( $self, $handle, $result, $searchexp, $n ) = @_;

	my $type = $handle->get_citation_type( 
			$self->{processor}->{results}->get_dataset, 
			$self->get_citation_id );

	if( $type eq "table_row" )
	{
		return $result->render_citation_link;
	}

	my $div = $handle->make_element( "div", class=>"ep_search_result" );
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

	my $form = $self->{handle}->render_form( "get" );
	$form->appendChild( 
		$self->{handle}->render_hidden_field ( "screen", $self->{processor}->{screenid} ) );		

	my $pphrase = $self->{processor}->{sconf}->{"preamble_phrase"};
	if( defined $pphrase )
	{
		$form->appendChild( $self->{handle}->html_phrase( $pphrase ));
	}

	$form->appendChild( $self->render_controls );

	my $table = $self->{handle}->make_element( "table", class=>"ep_search_fields" );
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

	my $frag = $self->{handle}->make_doc_fragment;

	foreach my $sf ( $self->{processor}->{search}->get_non_filter_searchfields )
	{
		$frag->appendChild( 
			$self->{handle}->render_row_with_help( 
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
		return $self->{handle}->make_doc_fragment;
	}

	my $menu = $self->{handle}->render_option_list(
			name=>"satisfyall",
			values=>[ "ALL", "ANY" ],
			default=>( defined $self->{processor}->{search}->{satisfy_all} && $self->{processor}->{search}->{satisfy_all}==0 ?
				"ANY" : "ALL" ),
			labels=>{ "ALL" => $self->{handle}->phrase( 
						"lib/searchexpression:all" ),
				  "ANY" => $self->{handle}->phrase( 
						"lib/searchexpression:any" )} );

	return $self->{handle}->render_row_with_help( 
			no_help => 1,
			label => $self->{handle}->html_phrase( 
				"lib/searchexpression:must_fulfill" ),  
			field => $menu,
	);
}

sub render_controls
{
	my( $self ) = @_;

	my $div = $self->{handle}->make_element( 
		"div" , 
		class => "ep_search_buttons" );
	$div->appendChild( $self->{handle}->render_action_buttons( 
		_order => [ "search", "newsearch" ],
		newsearch => $self->{handle}->phrase( "lib/searchexpression:action_reset" ),
		search => $self->{handle}->phrase( "lib/searchexpression:action_search" ) )
 	);
	return $div;
}



sub render_order_field
{
	my( $self ) = @_;

	return $self->{handle}->render_row_with_help( 
			no_help => 1,
			label => $self->{handle}->html_phrase( 
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
                $labels{$methods->{$_}} = $self->{handle}->phrase(
                	"ordername_".$self->{processor}->{search}->{dataset}->confid() . "_" . $_ );
        }

	return $self->{handle}->render_option_list(
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

	my $format = $self->{handle}->param( "output" );

	my @plugins = $self->_get_export_plugins( 1 );
		
	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "Export::$format" ) { $ok = 1; last; } }
	unless( $ok ) 
	{
		$self->{processor}->{search_subscreen} = "results";
		$self->{processor}->add_message(
			"error",
			$self->{handle}->html_phrase( "lib/searchexpression:export_error_format" ) );
		return;
	}
	
	$self->{processor}->{export_plugin} = $self->{handle}->plugin( "Export::$format" );
	$self->{processor}->{export_format} = $format;
	
	return 1;
}


sub export
{
	my( $self ) = @_;

	print $self->{processor}->{results}->export( $self->{processor}->{export_format} );
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->{processor}->{export_plugin}->param("mimetype") 
}






1;
