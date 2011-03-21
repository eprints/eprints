=head1 NAME

EPrints::Plugin::Screen::EPrint::Staff::ChangeOwner

=cut

package EPrints::Plugin::Screen::EPrint::Staff::ChangeOwner;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	#	$self->{priv} = # no specific priv - one per action

	$self->{actions} = [qw/ changeowner cancel setowner /];

	$self->{appears} = [ {
		place => "eprint_editor_actions",
		action => "changeowner",
		position => 1875,
	}, ];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->could_obtain_eprint_lock;
}

sub allow_changeowner
{
	my( $self ) = @_;

	return 0 unless $self->could_obtain_eprint_lock;
	return $self->allow( "eprint/edit:editor" );
}
sub allow_cancel
{
	&allow_changeowner;
}
sub allow_setowner
{
	&allow_changeowner;
}
sub action_changeowner {};
sub action_cancel
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";
}
sub action_setowner
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};
	my $dataset = $eprint->{dataset};

	my $database = $session->get_database;

	my $username = $session->param( "username" );

	return unless EPrints::Utils::is_set( $username );

	my $user = EPrints::DataObj::User::user_with_username( $session, $username );

	unless( $user )
	{
		$self->{processor}->add_message( "error",
				$self->html_phrase( "invaliduser",
			) );

		return;
	}

	$eprint->set_value( "userid", $user->get_id );
	$eprint->commit;

	$self->{processor}->add_message( "message",
		$self->html_phrase( "changedowner",
			user => $user->render_citation,
	) );
}

sub redirect_to_me_url
{
	my( $self ) = @_;

	return $self->SUPER::redirect_to_me_url.$self->workflow->get_state_params( $self->{processor} );
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $eprint = $self->{processor}->{eprint};

	my( $html, $table, $p, $span );

	$html = $session->make_doc_fragment;

	my $internal = $self->{processor}->{internal};

	my $form = $session->render_input_form(
			fields => [
				$session->get_repository->get_dataset( "user" )->get_field( "username" ),
			],
			hidden_fields => {
				eprintid => $eprint->get_id,
			},
			show_names => 1,
			show_help => 1,
			buttons => {
				setowner => $self->phrase( "changeowner" ),
				cancel => $self->phrase( "cancel" ),
			},
			);

	$html->appendChild( $form );
	$form->appendChild( $session->render_hidden_field( "screen", $self->{processor}->{screenid} ) );

	return $html;
}

1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

