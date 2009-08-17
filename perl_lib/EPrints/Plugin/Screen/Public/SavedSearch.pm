
package EPrints::Plugin::Screen::Public::SavedSearch;

use EPrints::Plugin::Screen::User::SavedSearch::Run;

@ISA = ( 'EPrints::Plugin::Screen::User::SavedSearch::Run' );

use strict;


sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ export_redir export /]; 

	$self->{appears} = [];

	return $self;
}

sub register_furniture
{
	my( $self ) = @_;

	return $self->{handle}->make_doc_fragment;
}

sub render_toolbar
{
	my( $self ) = @_;

	return $self->{handle}->make_doc_fragment;
}

sub from
{
	my( $self ) = @_;

        my $public = $self->{processor}->{savedsearch}->get_value( "public" );
	if( $public ne "TRUE" )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error",
			$self->html_phrase( "not_public" ) );
		return;
	}

	$self->SUPER::from;
}


sub can_be_viewed
{
	my( $self ) = @_;

	return 1;
}

sub properties_from
{
	my( $self ) = @_;


	my $searchid = $self->{handle}->param( "savedsearchid" );
	$self->{processor}->{savedsearchid} = $searchid;
	$self->{processor}->{savedsearch} = new EPrints::DataObj::SavedSearch( 
					$self->{handle}, $searchid );

	if( !defined $self->{processor}->{savedsearch} )
	{
		$self->{processor}->{screenid} = "Error";
		$self->{processor}->add_message( "error", 
			$self->html_phrase(
				"no_such_saved_search",
				id => $self->{handle}->make_text( 
						$self->{processor}->{savedsearchid} ) ) );
		return;
	}

}


1;
