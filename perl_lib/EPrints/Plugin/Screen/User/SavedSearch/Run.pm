
package EPrints::Plugin::Screen::User::SavedSearch::Run;

use EPrints::Plugin::Screen::User::SavedSearch;

@ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ export_redir export /]; 

	$self->{appears} = [
		{
			place => "saved_search_actions",
			position => 100,
		}
	];

	return $self;
}

sub from
{
	my( $self ) = @_;

	my $ds = $self->{processor}->{savedsearch}->get_dataset;
	my $spec = $self->{processor}->{savedsearch}->get_value( 'spec' );
	$self->{processor}->{search} = $ds->get_field( "spec" )->make_searchexp( $self->{session}, $spec );
	$self->{processor}->{results} = $self->{processor}->{search}->perform_search;

	$self->SUPER::from;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/perform" );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	$self->{processor}->{results}->cache;
	my $cacheid = $self->{processor}->{results}->get_cache_id;

	my $export_div = $self->{session}->make_element( "div", class=>"ep_search_export" );
	$export_div->appendChild( $self->render_export_bar );

	my %opts = (
		params => { 
			screen => $self->{processor}->{screenid},
			savedsearchid => $self->{processor}->{savedsearchid},
		},
		render_result => sub {
			my( $session, $result, $searchexp, $n ) = @_;
			my $div = $session->make_element( "div", class=>"ep_search_result" );
			$div->appendChild( 
				$result->render_citation_link(
					'result',
					n => [$n,"INTEGER"] ) );
			return $div;
		},
		render_result_params => $self->{processor}->{results},
		above_results => $export_div,
		container => $self->{session}->make_element( "table" ),
#		page_size => $self->{page_size},
	);

	my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_search", $self->{processor}->{results}, %opts ) );

	return $page;
}
	
sub render_title
{
	my( $self ) = @_;

	my $f = $self->{session}->make_doc_fragment;
	$f->appendChild( $self->{processor}->{savedsearch}->render_description );
	return $f;
}

sub allow_export_redir { return 1; }

sub action_export_redir
{
	my( $self ) = @_;

	my $format = $self->{session}->param( "_output" );

	$self->{processor}->{redirect} = $self->export_url( $format );
}

sub allow_export { return 1; }

sub action_export
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "export";

	return;
}


sub _get_export_plugins
{
	my( $self ) = @_;

	return $self->{session}->plugin_list( 
			type=>"Export",
			can_accept=>"list/eprint",
			is_visible=>"all" );
}

sub export_url
{
	my( $self, $format ) = @_;

	my $plugin = $self->{session}->plugin( "Export::".$format );

	my $savedsearchid = $self->{session}->param( "savedsearchid" );
	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $fullurl = "$url/export_".$self->{session}->get_repository->get_id."_".$format.$plugin->param("suffix")."?savedsearchid=$savedsearchid&_output=$format&_action_export=1&screen=".$self->{processor}->{screenid};
	return $fullurl;
}


sub render_export_bar
{
	my( $self ) = @_;
	my @plugins = $self->_get_export_plugins;
	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $savedsearchid = $self->{session}->param( "savedsearchid" );
	my $url = $self->{session}->get_uri();
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
	my $select = $session->make_element( "select", name=>"_output" );
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
		$session->render_hidden_field( "_cache", $cacheid ) ); 
	$button->appendChild( 
		$session->render_hidden_field( "savedsearchid", $savedsearchid, ) );

	return $session->html_phrase( "lib/searchexpression:export_section",
					feeds => $feeds,
					tools => $tools,
					count => $session->make_text( 
						$self->{processor}->{results}->count ),
					menu => $select,
					button => $button );
}


sub wishes_to_export
{
	my( $self ) = @_;

	return 0 unless $self->{processor}->{search_subscreen} eq "export";

	my $format = $self->{session}->param( "_output" );

	my @plugins = $self->{session}->plugin_list(
		type=>"Export",
		can_accept=>"list/eprint",
		is_visible=>"all",
	);
		
	my $ok = 0;
	foreach( @plugins ) { if( $_ eq "Export::$format" ) { $ok = 1; last; } }
	unless( $ok ) 
	{
		$self->{session}->build_page(
			$self->{session}->html_phrase( "lib/searchexpression:export_error_title" ),
			$self->{session}->html_phrase( "lib/searchexpression:export_error_format" ),
			"export_error" );
		$self->{session}->send_page;
		return;
	}
	
	$self->{processor}->{export_plugin} = $self->{session}->plugin( "Export::$format" );
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

