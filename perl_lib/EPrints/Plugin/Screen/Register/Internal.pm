=head1 NAME

EPrints::Plugin::Screen::Register::Internal

=cut

package EPrints::Plugin::Screen::Register::Internal;

@ISA = qw( EPrints::Plugin::Screen::Register );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
		{
			place => "register_tabs",
			position => 100,
		},
	];

	return $self;
}

sub action_register
{
	my( $self ) = @_;

	return if !$self->SUPER::action_register;

	my $processor = $self->{processor};
	my $repo = $self->{repository};

	my $dataset = $repo->dataset( "user" );

	my $item = $processor->{item};

	my $email = $item->value( "newemail" );

	if( $processor->{min} )
	{
		$item->set_value( "username", $email );
	}

	my $username = $item->value( "username" );

	if( defined EPrints::DataObj::User::user_with_email( $repo, $email ) )
	{
		$processor->add_message( "error", $repo->html_phrase(
			"cgi/register:email_exists", 
			email=>$repo->make_text( $email ) ) );
		return;
	}

	if( $repo->can_call( "check_registration_email" ) )
	{
		if( !$repo->call( "check_registration_email", $repo, $email ) )
		{
			$processor->add_message( "error", $repo->html_phrase(
				"cgi/register:email_denied",
				email=>$repo->make_text( $email ) ) );
			return;
		}
	} 

	if( defined EPrints::DataObj::User::user_with_username( $repo, $username ) )
	{
		$processor->add_message( "error", $repo->html_phrase(
			"cgi/register:username_exists", 
			username=>$repo->make_text( $username ) ) );
		return;
	}

	my $user_data = $item->get_data;
	$user_data->{email} = delete $user_data->{newemail};

	my $user = $self->register_user( $user_data );

	$processor->{user} = $user;

	return 1;
}

sub render
{
	my( $self ) = @_;

	return $self->SUPER::render_workflow();
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

