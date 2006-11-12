
package EPrints::Plugin::Screen::Staff::EPrintSearch;

@ISA = ( 'EPrints::Plugin::Screen::AbstractSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "other_tools",
			position => 300,
		},
	];

	return $self;
}

sub search_dataset
{
	my( $self ) = @_;

	return $self->{session}->get_repository->get_dataset( "eprint" );
}

sub search_filters
{
	my( $self ) = @_;

	return;
}

sub allow_export { return 1; }

sub allow_export_redir { return 1; }

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "staff/eprint_search" );
}

sub from
{
	my( $self ) = @_;

	my $sconf = {
		staff => 1,
		dataset_id => "eprint",
		citation => $self->{session}->get_repository->get_conf( "search","advanced","citation" ),
	};
		
	my $adv_fields = $self->{session}->get_repository->get_conf( "search","advanced","search_fields" );
	$sconf->{"search_fields"} = [
		{ meta_fields => [ "eprintid" ] },
		{ meta_fields => [ "userid" ] },
		{ meta_fields => [ "eprint_status" ], default=>'archive buffer' },
		{ meta_fields => [ "dir" ] },
		@{$adv_fields},
	];

	$self->{processor}->{sconf} = $sconf;

	$self->SUPER::from;
}

sub _vis_level
{
	my( $self ) = @_;

	return "staff";
}

sub get_controls_before
{
	my( $self ) = @_;

	return $self->get_basic_controls_before;	
}

sub render_result_row
{
	my( $self, $session, $result, $searchexp, $n ) = @_;

	return $result->render_citation_link_staff(
			$self->{processor}->{sconf}->{citation},  #undef unless specified
			n => [$n,"INTEGER"] );
}


sub render_results_intro
{
	my( $self ) = @_;

	my $h2 = $self->{session}->make_element( "h2", class=>"ep_search_desc" );
	$h2->appendChild( $self->{processor}->{search}->render_conditions_description );
	return $h2;
}



