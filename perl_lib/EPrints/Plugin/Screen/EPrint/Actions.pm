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

	return 0 unless
		scalar $self->action_list( "eprint_actions" )
		|| scalar $self->action_list( "eprint_editor_actions" );

	return $self->who_filter;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $user = $session->current_user;
	my $staff = $user->get_type eq "editor" || $user->get_type eq "admin";

	my $frag = $session->make_doc_fragment;
	my $table = $session->make_element( "table" );
	$frag->appendChild( $table );
	my( $tr, $th, $td );

	$tr = $table->appendChild( $session->make_element( "tr" ) );
	$td = $tr->appendChild( $session->make_element( "td" ) );
	$td->appendChild( $self->render_action_list( "eprint_actions", ['eprintid'] ) );

	$tr = $table->appendChild( $session->make_element( "tr" ) );
	$th = $tr->appendChild( $session->make_element( "th", class => "ep_title_row" ) );
	$th->appendChild( $session->html_phrase( "Plugin/Screen/EPrint/Actions/Editor:title" ) );

	$tr = $table->appendChild( $session->make_element( "tr" ) );
	$td = $tr->appendChild( $session->make_element( "td" ) );
	$td->appendChild( $self->render_action_list( "eprint_editor_actions", ['eprintid'] ) );

	$tr = $table->appendChild( $session->make_element( "tr" ) );
	$th = $tr->appendChild( $session->make_element( "th", class => "ep_title_row" ) );
	$th->appendChild( $session->html_phrase( "Plugin/Screen/EPrint/Export:title" ) );

	$tr = $table->appendChild( $session->make_element( "tr" ) );
	$td = $tr->appendChild( $session->make_element( "td" ) );
	$td->appendChild(
		$session->make_element( "div", class => "ep_block" )
	)->appendChild(
		$self->{processor}->{eprint}->render_export_bar( $staff )
	);

	return $frag;
}

1;
