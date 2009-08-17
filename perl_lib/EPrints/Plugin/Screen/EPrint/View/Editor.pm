
package EPrints::Plugin::Screen::EPrint::View::Editor;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{staff} = 1;

	$self->{icon} = "action_view.png";

	$self->{appears} = [
		{
			place => "eprint_review_actions",
			position => 10,
		},
	];

	return $self;
}

sub who_filter { return 8; }

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $url = $self->{processor}->{eprint}->get_url;

	my $div = $self->{handle}->make_element( "div", class=>"ep_block" );
	$div->appendChild( $self->{handle}->html_phrase( "cgi/users/edit_eprint:staff_item_is_in_".$status,
		link => $self->{handle}->render_link( $url ), 
		url  => $self->{handle}->make_text( $url ) ) );

	return $div;
}

sub render_common_action_buttons
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	return $self->render_action_list_bar( "eprint_actions_editor_$status", ['eprintid'] );
}


sub about_to_render 
{
	my( $self ) = @_;
}

1;

