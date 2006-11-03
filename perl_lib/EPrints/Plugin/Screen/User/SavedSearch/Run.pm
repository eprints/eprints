
package EPrints::Plugin::Screen::User::SavedSearch::Run;

use EPrints::Plugin::Screen::User::SavedSearch;

@ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "saved_search_actions",
			position => 100,
		}
	];

	return $self;
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
	
	my $ds = $self->{processor}->{savedsearch}->get_dataset;

	foreach my $fid ( "frequency","mailempty","public" )
	{
		next unless $self->{processor}->{savedsearch}->is_set( $fid );
		my $strong = $session->make_element( "strong" );
		$strong->appendChild( $ds->get_field( $fid )->render_name( $session ) );
		$strong->appendChild( $session->make_text( ": ") );
		$page->appendChild( $strong );
		$page->appendChild( $self->{processor}->{savedsearch}->render_value( $fid ) );
		$page->appendChild( $session->make_text( ". ") );
	}

	$page->appendChild( $self->render_action_list_bar( "saved_search_actions", ['userid','savedsearchid'] ) );

	my $spec = $self->{processor}->{savedsearch}->get_value( 'spec' );
	my $search = $ds->get_field( "spec" )->make_searchexp( $session, $spec );
	my $list = $search->perform_search;
	$list->cache;
	my $cacheid = $list->get_cache_id;

	my %opts = (
#		pins => \%bits,
#		controls_before => \@controls_before,
		phrase => "lib/searchexpression:results_page",
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
		render_result_params => $list,
#		page_size => $self->{page_size},
	);

	#my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_search", $list, %opts ) );

	return $page;
}
	

1;
