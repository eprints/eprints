package EPrints::Plugin::Screen::Register;

# This plugin just adds a link to the /cgi/register script

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{appears} = [
# See cfg.d/dynamic_template.pl
#		{
#			place => "key_tools",
#			position => 100,
#		},
	];
	$self->{actions} = [qw( register )];

	return $self;
}

sub allow_register { shift->can_be_viewed }
sub can_be_viewed
{
	my( $self ) = @_;

	return !defined $self->{session}->current_user;
}

sub render_action_link
{
	my( $self ) = @_;

	my $repo = $self->{session};

	my $link = $repo->xml->create_element( "a",
		href => $repo->config( "http_cgiroot" ) . "/register"
	);
	$link->appendChild( $self->render_title );

	return $link;
}

1;
