package EPrints::Plugin::Screen::Admin;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "other_tools",
			position => 100,
		},
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list( "admin_actions" );
	return 1;
}

sub render
{
	my( $self ) = @_;
	if( EPrints::Index::has_stalled )
	{
		my $index_screen = $self->{session}->plugin( "Screen::Admin::Indexer", processor => $self->{processor} );
		my $force_start_button = $self->render_action_button_if_allowed( 
		{ 
			action => "force_start_indexer", 
			screen => $index_screen, 
			screen_id => $index_screen->{id} 
		} );

		$self->{processor}->add_message( 
			"warning",
			$self->html_phrase( "indexer_stalled", force_start_button => $force_start_button ) 
		);
	}
	elsif( !EPrints::Index::is_running )
	{
		my $index_screen = $self->{session}->plugin( "Screen::Admin::Indexer", processor => $self->{processor} );
		my $start_button = $self->render_action_button_if_allowed( 
		{ 
			action => "start_indexer", 
			screen => $index_screen, 
			screen_id => $index_screen->{id} ,
		} );
 
		$self->{processor}->add_message( 
			"warning", 
			$self->html_phrase( "indexer_not_running", start_button => $start_button ) 
		);
	}

	return $self->render_action_list( "admin_actions" );
}

1;
