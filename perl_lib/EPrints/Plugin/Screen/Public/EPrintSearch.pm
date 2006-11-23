package EPrints::Plugin::Screen::Public::EPrintSearch;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub register_furniture
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}

sub render_toolbar
{
	my( $self ) = @_;

	return $self->{session}->make_doc_fragment;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "eprint_search" );
}

sub allow_export { return 1; }

sub allow_export_redir { return 1; }

sub search_dataset
{
	my( $self ) = @_;

	$self->{session}->get_repository->get_dataset( "archive" );
}

sub search_filters
{
	my( $self ) = @_;

	return { meta_fields=>[ 'metadata_visibility' ], value=>'show', match=>'EX', describe=>0 };
}

sub _vis_level
{
	my( $self ) = @_;

	return "all";
}

sub get_controls_before
{
	my( $self ) = @_;

	my @controls_before = $self->get_basic_controls_before;	

	my $cacheid = $self->{processor}->{results}->{cache_id};
	my $escexp = $self->{processor}->{search}->serialise;

	my $cuser = $self->{session}->current_user;
	if( defined $cuser )
	{
		if( $cuser->allow( "create_saved_search" ) )
		{
			my $base = $self->{session}->get_repository->get_conf( "userhome" );
			push @controls_before, {
				url => $base."?screen=User::SaveSearch&cache=$cacheid&_action_create=1",
				label => $self->{session}->html_phrase( "lib/searchexpression:savesearch" ),
			};
		}
	}

	return @controls_before;
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	return $result->render_citation_link(
			$self->{processor}->{sconf}->{citation},  #undef unless specified
			n => [$n,"INTEGER"] );
}

sub paginate_opts
{
	my( $self ) = @_;

	my %opts = $self->SUPER::paginate_opts;
	
	return %opts;
}


1;
