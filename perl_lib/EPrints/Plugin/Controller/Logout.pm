package EPrints::Plugin::Controller::Logout;

use strict;
use EPrints;
use EPrints::Const qw( :http );

our @ISA = qw/ EPrints::Plugin::Controller /;

sub new
{
	my( $class, %params ) = @_;
	
	$params{priority} = 1000;

	my $self = $class->SUPER::new(%params);

	$self->register_endpoint(
		qr[^/logout$],
	);

	return $self;
}

sub GET
{
	my( $self ) = @_;

	my $repo = $self->repository;
	my $request = $self->{request};

	if( $repo->current_user )
	{
		$repo->logout;
	}

	# TODO from conf (url)
	return EPrints::Apache::redir( $request, "/" );
}

1;
