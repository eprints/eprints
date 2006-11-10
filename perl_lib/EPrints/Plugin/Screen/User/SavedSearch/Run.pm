
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
	my $search = $ds->get_field( "spec" )->make_searchexp( $self->{session}, $spec );
	$self->{processor}->{results} = $search->perform_search;

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

	my $page = $session->make_doc_fragment;
	
	$self->{processor}->{results}->cache;
	my $cacheid = $self->{processor}->{results}->get_cache_id;

	my $export_div = $self->{session}->make_element( "div", class=>"ep_search_export" );
	$export_div->appendChild( $self->render_export_select );

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

	#my $page = $self->{session}->render_form( "GET" );
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

	my $savedsearchid = $self->{session}->param( "savedsearchid" );
	my $userid = $self->{session}->param( "userid" );
	my $format = $self->{session}->param( "_output" );
	my $plugin = $self->{session}->plugin( "Export::".$format );

	my $url = $self->{session}->get_uri();
	#cjg escape URL'ify urls in this bit... (4 of them?)
	my $fullurl = "$url/export_".$self->{session}->get_repository->get_id."_".$format.$plugin->param("suffix")."?userid=$userid&_output=$format&_action_export=1&savedsearchid=$savedsearchid&screen=".$self->{processor}->{screenid};

	$self->{processor}->{redirect} = $fullurl;
}

sub allow_export { return 1; }

sub action_export
{
	my( $self ) = @_;

	$self->{processor}->{search_subscreen} = "export";

	return;
}



sub render_export_select
{
	my( $self ) = @_;

	my @plugins =  $self->{session}->plugin_list( 
			type=>"Export",
			can_accept=>"list/eprint",
			is_visible=>"all", 
	);
	if( scalar @plugins == 0 ) 
	{
		return $self->{session}->make_doc_fragment;
	}
	my $form = $self->{session}->render_form( "GET" );

	my $select = $self->{session}->make_element( "select", name=>"_output" );
	foreach my $plugin_id ( @plugins ) {
		$plugin_id =~ m/^[^:]+::(.*)$/;
		my $id = $1;
		my $option = $self->{session}->make_element( "option", value=>$id );
		my $plugin = $self->{session}->plugin( $plugin_id );
		$option->appendChild( $plugin->render_name );
		$select->appendChild( $option );
	}
	my $button = $self->{session}->make_doc_fragment;
	$button->appendChild( $self->{session}->render_button(
			name=>"_action_export_redir", 
			value=>$self->{session}->phrase( "lib/searchexpression:export_button" ) ) );
	$button->appendChild( 
		$self->{session}->render_hidden_field( "screen", $self->{processor}->{screenid} ) ); 
	my $savedsearchid = $self->{session}->param( "savedsearchid" );
	my $userid = $self->{session}->param( "userid" );
	$button->appendChild( $self->{session}->render_hidden_field( "savedsearchid", $savedsearchid ) ); 
	$button->appendChild( $self->{session}->render_hidden_field( "userid", $userid, ) );

	$form->appendChild( $self->{session}->html_phrase( "lib/searchexpression:export_section",
				menu => $select,
				button => $button ));
	return $form;
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

