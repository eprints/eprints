=head1 NAME

EPrints::Plugin::Screen::AbstractSearch

=cut

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
		dataset => $self->search_dataset->id,
		_action_export => 1,
		output => $format,
		exp => $self->{processor}->{search}->serialise,
		n => scalar($self->{session}->param( "n" )),
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

	my $filters = $self->{processor}->{filters};

	return defined $filters ? @$filters : ();
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
		my %params = map { $_ => 1 } $self->{session}->param();
		delete $params{screen};
		delete $params{dataset};
		if( scalar keys %params )
		{
			$self->{processor}->{action} = "search";
		}
	}

	$self->{processor}->{search} = EPrints::Search->new(
		keep_cache => 1,
		session => $self->{session},
		filters => [$self->search_filters],
		dataset => $self->search_dataset,
		%{$self->{processor}->{sconf}} );


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

	return "staff" if defined $self->{session}->current_user && $self->{session}->current_user->is_staff;

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

sub render_export_links
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $q = $repo->param( "q" );
	return $xml->create_document_fragment if !defined $q;

	my $mime_type = $self->{processor}->{export_plugin}->param( "mimetype" );
	my $offset = $self->{processor}->{export_offset};
	my $n = $self->{processor}->{export_n};

	my $links = $xml->create_document_fragment;

	my $base_url = $repo->current_url( host => 1, query => 1 );
	my @query = $base_url->query_form;
	foreach my $i (reverse(0 .. int($#query/2)))
	{
		splice(@query, $i*2, 2) if $query[$i*2] eq 'search_offset';
	}
	$base_url->query_form( @query );
	$base_url->query( undef ) if !@query;

	$links->appendChild( $xml->create_element( 'link',
		rel => 'first',
		type => $mime_type,
		href => "$base_url",
		) );
	if( $offset >= $n )
	{
		$links->appendChild( $xml->create_text_node( "\n" ) );
		$links->appendChild( $xml->create_element( 'link',
			rel => 'prev',
			type => $mime_type,
			href => "$base_url&search_offset=".($offset-$n),
			) );
	}
	if( $self->{processor}->{results}->count >= ($offset+$n) )
	{
		$links->appendChild( $xml->create_text_node( "\n" ) );
		$links->appendChild( $xml->create_element( 'link',
			rel => 'next',
			type => $mime_type,
			href => "$base_url&search_offset=".($offset+$n),
			) );
	}
	$links->appendChild( $xml->create_text_node( "\n" ) );
	$links->appendChild( $xml->create_element( 'opensearch:Query',
		role => 'request',
		searchTerms => $q,
		startIndex => $self->{processor}->{export_offset},
		) );
	$links->appendChild( $xml->create_text_node( "\n" ) );
	$links->appendChild( $xml->create_data_element( 'opensearch:itemsPerPage',
		$self->{processor}->{export_n},
		) );
	$links->appendChild( $xml->create_text_node( "\n" ) );
	$links->appendChild( $xml->create_data_element( 'opensearch:startIndex',
		$self->{processor}->{export_offset},
		) );
	$links->appendChild( $xml->create_text_node( "\n" ) );
	$links->appendChild( $xml->create_element( 'link',
		rel => 'self',
		type => $self->{processor}->{export_plugin}->param( "mimetype" ),
		href => $repo->current_url( host => 1, query => 1 ),
		) );
	$links->appendChild( $xml->create_text_node( "\n" ) );
	$links->appendChild( $xml->create_element( 'link',
		rel => 'search',
		type => 'application/opensearchdescription+xml',
		title => $repo->phrase( "lib/searchexpression:search" ),
		href => $repo->current_url( host => 1, path => 'cgi', 'opensearchdescription' ),
		) );

	return $links;
}

sub render_export_bar
{
	my( $self ) = @_;

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
	# EPrints Services/af05v 2009-03-02 default export plugin
	my $default_export_plugin = $session->config( 'default_export_plugin' ) || '_NULL_';
	# EPrints Services/af05v end
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
			# EPrints Services/af05v 2009-03-02 select default export plugin
			$option->setAttribute( selected => 'selected' ) if( $id eq $default_export_plugin );
			# EPrints Services/af05v end
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
	$button->appendChild( $self->render_hidden_bits );
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

	my $baseurl = URI->new( $self->{session}->get_uri );
	$baseurl->query_form(
		cache => $cacheid,
		exp => $escexp,
		screen => $self->{processor}->{screenid},
		dataset => $self->search_dataset->id,
		order => $self->{processor}->{search}->{custom_order},
	);
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

	my %bits = ();

	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;
	my $order = $self->{processor}->{search}->{custom_order};

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
	$form->appendChild( $self->render_hidden_bits );
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
			order => $order,
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
		!$self->{processor}->{results}->isa( "EPrints::List" ) )
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

	$form->appendChild( $self->render_hidden_bits );

	$form->appendChild( $self->render_preamble );

	$form->appendChild( $self->render_controls );

	my $table = $self->{session}->make_element( "table", class=>"ep_search_fields" );
	$form->appendChild( $table );

	$table->appendChild( $self->render_search_fields );

	$table->appendChild( $self->render_anyall_field );

	$table->appendChild( $self->render_order_field );

	$form->appendChild( $self->render_controls );

	return( $form );
}

sub render_preamble
{
	my( $self ) = @_;

	my $pphrase = $self->{processor}->{sconf}->{"preamble_phrase"};
	if( defined $pphrase )
	{
		return $self->{"session"}->html_phrase( $pphrase );
	}

	return $self->{session}->make_doc_fragment;
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
	$raworder = "" if !defined $raworder;

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

# redirecting from a POST will lose all our parameters, although we always use
# GET internally so this doesn't normally affect anything
sub redirect_to_me_url
{
	my( $self ) = @_;

	return undef;
}

# $method_map = $searche->order_methods

sub wishes_to_export
{
	my( $self ) = @_;

	return 0 unless $self->{processor}->{search_subscreen} eq "export";

	my $format = $self->{session}->param( "output" );

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
	
	$self->{processor}->{export_format} = $format;
	$self->{processor}->{export_plugin} = $self->{session}->plugin( "Export::$format" );
	$self->{processor}->{export_offset} = $self->{session}->param( "search_offset" );
	$self->{processor}->{export_n} = $self->{session}->param( "n" );
	
	return 1;
}


sub export
{
	my( $self ) = @_;

	my $results = $self->{processor}->{results};

	my $offset = $self->{processor}->{export_offset};
	my $n = $self->{processor}->{export_n};

	if( EPrints::Utils::is_set( $offset ) || EPrints::Utils::is_set( $n ) )
	{
		$offset = 0 if !EPrints::Utils::is_set( $offset );
		$n = $results->count if !EPrints::Utils::is_set( $n );
		$offset += 0 if defined $offset;
		$n += 0 if defined $n;
		my $ids = $results->get_ids( $offset, $n );
		$results = EPrints::List->new(
			session => $self->{session},
			dataset => $results->{dataset},
			ids => $ids );
	}

	my $format = $self->{processor}->{export_format};
	my $plugin = $self->{session}->plugin( "Export::" . $format );

	my %arguments = map {
		$_ => scalar($self->{session}->param( $_ ))
	} $plugin->arguments;

	$plugin->initialise_fh( *STDOUT );
	$plugin->output_list(
		list => $results,
		fh => *STDOUT,
		links => $self->render_export_links,
		%arguments
	);
}

sub export_mimetype
{
	my( $self ) = @_;

	return $self->{processor}->{export_plugin}->param("mimetype") 
}






1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

