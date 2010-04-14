package EPrints::Plugin::Screen::EPrint::Actions::Editor;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::Actions' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "eprint_view_tabs",
			position => 350,
		}
	];

	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	return 0 unless scalar $self->action_list( "eprint_editor_actions" );

	return $self->who_filter;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	return $self->render_action_list( "eprint_editor_actions", ['eprintid'] );
}

1;
