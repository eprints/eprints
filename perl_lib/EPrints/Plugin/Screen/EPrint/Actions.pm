package EPrints::Plugin::Screen::EPrint::Actions;

our @ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 300,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list( "eprint_actions" );

	return $self->who_filter;
}

sub who_filter { return 4; }

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	return $self->render_action_list( "eprint_actions", ['eprintid'] );
}

1;
