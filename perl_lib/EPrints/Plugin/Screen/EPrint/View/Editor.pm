
package EPrints::Plugin::Screen::EPrint::View::Editor;

use EPrints::Plugin::Screen::EPrint::View;

@ISA = ( 'EPrints::Plugin::Screen::EPrint::View' );

use strict;


sub who_filter { return 8; }

sub render_status
{
	my( $self ) = @_;

	my $status = $self->{processor}->{eprint}->get_value( "eprint_status" );

	my $status_fragment = $self->{session}->make_doc_fragment;
	$status_fragment->appendChild( $self->{session}->html_phrase( "cgi/users/edit_eprint:item_is_in_".$status ) );

	my @staff_actions = ();
	foreach my $action (
		"reject_with_email",
		"move_inbox_buffer", 
		"move_buffer_archive",
		"move_archive_buffer", 
		"move_archive_deletion",
		"move_deletion_archive",
	) 
	{
		push @staff_actions, $action if( $self->allow( "action/eprint/$action" ) );
	}
	if( scalar @staff_actions )
	{
		my %buttons = ( _order=>[] );
		foreach my $action ( @staff_actions )
		{
			push @{$buttons{_order}}, $action;
			$buttons{$action} = $self->{session}->phrase( "priv:action/eprint/".$action );
		}
		my $form = $self->render_form;
		$form->appendChild( $self->{session}->render_action_buttons( %buttons ) );
		$status_fragment->appendChild( $form );
	} 

	return $status_fragment;
#	return $self->{session}->render_toolbox( 
#			$self->{session}->make_text( "Status" ),
#			$status_fragment );
}



sub about_to_render 
{
	my( $self ) = @_;
}

1;

