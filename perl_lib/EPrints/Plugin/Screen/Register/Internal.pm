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

1;
