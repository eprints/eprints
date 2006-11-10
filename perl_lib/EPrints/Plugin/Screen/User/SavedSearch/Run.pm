
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

	my $spec = $self->{processor}->{savedsearch}->get_value( 'spec' );
	my $search = $ds->get_field( "spec" )->make_searchexp( $session, $spec );
	my $list = $search->perform_search;
	$list->cache;
	my $cacheid = $list->get_cache_id;

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
		render_result_params => $list,
		container => $self->{session}->make_element( "table" ),
#		page_size => $self->{page_size},
	);

	#my $page = $self->{session}->render_form( "GET" );
	$page->appendChild( EPrints::Paginate->paginate_list( $self->{session}, "_search", $list, %opts ) );

	return $page;
}
	

1;
