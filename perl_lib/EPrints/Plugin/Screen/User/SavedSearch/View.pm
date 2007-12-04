
package EPrints::Plugin::Screen::User::SavedSearch::View;

use EPrints::Plugin::Screen::User::SavedSearch;

@ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return $self->allow( "saved_search/view" );
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

	return $page;
}
	

1;
