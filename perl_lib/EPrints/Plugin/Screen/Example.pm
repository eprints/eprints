
package EPrints::Plugin::Screen::Example;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{priv} = undef;

	return $self;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $user = $session->current_user;

	return $session->make_doc_fragment;
}

1;
